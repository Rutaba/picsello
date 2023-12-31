defmodule Picsello.OrdersTest do
  use Picsello.DataCase, async: true
  alias Picsello.{Orders, Cart, Cart.Order}
  import Money.Sigils

  setup do
    test_pid = self()

    Tesla.Mock.mock_global(fn
      %{method: :post} = request ->
        send(test_pid, {:zapier_request, request})

        body = %{
          "attempt" => "1234",
          "id" => "1234",
          "request_id" => "1234",
          "status" => "success"
        }

        %Tesla.Env{status: 200, body: body}
    end)
  end

  describe "all" do
    def order_with_product(gallery, opts) do
      whcc_id = Keyword.get(opts, :whcc_id)
      placed_at = Keyword.get(opts, :placed_at, DateTime.utc_now())

      gallery_client =
        insert(:gallery_client, %{email: "client-1@example.com", gallery_id: gallery.id})

      insert(:order,
        gallery_client: gallery_client,
        gallery: gallery,
        placed_at: placed_at,
        products: build_list(1, :cart_product, whcc_product: build(:product, whcc_id: whcc_id))
      )
    end

    test "preloads products" do
      gallery = insert(:gallery)

      order_with_product(gallery, whcc_id: "123")

      order_with_product(gallery,
        whcc_id: "abc",
        placed_at: DateTime.utc_now() |> DateTime.add(-100)
      )

      assert [
               %{products: [%{whcc_product: %{whcc_id: "123"}}]},
               %{products: [%{whcc_product: %{whcc_id: "abc"}}]}
             ] = Orders.all(gallery.id)
    end
  end

  describe "whcc updates" do
    setup do
      Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)

      user = insert(:user, email: "photographer@example.com") |> onboard!()

      job =
        insert(:lead, package: insert(:package, currency: "USD"), user: user) |> promote_to_job()

      gallery = insert(:gallery, job: job) |> Map.put(:credits_available, true)

      gallery_client =
        insert(:gallery_client, %{email: "client-1@example.com", gallery_id: gallery.id})

      cart_product = build(:cart_product)

      order = Cart.place_product(cart_product, gallery, gallery_client)

      entry_id =
        order
        |> Order.number()
        |> to_string()

      [
        order:
          order
          |> Order.store_delivery_info(%{email: "customer@example.com", name: "John Customer"})
          |> Repo.update!()
          |> Order.whcc_order_changeset(
            build(:whcc_order_created, entry_id: entry_id, total: ~M[100]USD)
          )
          |> Repo.update!(),
        entry_id: entry_id
      ]
    end

    def processing_status(entry_id, sequence_number),
      do: %Picsello.WHCC.Webhooks.Status{
        entry_id: entry_id,
        event: "Processed",
        sequence_number: sequence_number,
        status: "Accepted"
      }

    def processing_event(entry_id, sequence_number),
      do: %Picsello.WHCC.Webhooks.Event{
        entry_id: entry_id,
        event: "Shipped",
        sequence_number: sequence_number,
        shipping_info: [
          %Picsello.WHCC.Webhooks.ShippingInfo{
            carrier: "FedEx",
            ship_date: ~U[2018-12-31 12:18:38Z],
            tracking_number: "512376671311227",
            tracking_url: "http://www.fedex.com/Tracking?tracknumbers=512376671311227",
            weight: 0.35
          }
        ]
      }

    test "find and save processing status", %{order: order} do
      assert %{
               whcc_order: %{
                 entry_id: entry_id,
                 orders: [%{whcc_processing: nil, sequence_number: sequence_number}]
               }
             } = order

      Orders.update_whcc_order(processing_status(entry_id, sequence_number), PicselloWeb.Helpers)

      assert %{whcc_order: %{orders: [%{whcc_processing: %{status: "Accepted"}}]}} =
               Repo.reload!(order)
    end

    test "updates correct sub-order", %{order: order, entry_id: entry_id} do
      order =
        order
        |> Order.whcc_order_changeset(
          build(:whcc_order_created,
            entry_id: entry_id,
            orders: build_list(2, :whcc_order_created_order)
          )
        )
        |> Repo.update!()

      assert %{
               whcc_order: %{
                 entry_id: entry_id,
                 orders: [%{}, %{whcc_processing: nil, sequence_number: sequence_number}]
               }
             } = order

      Orders.update_whcc_order(processing_status(entry_id, sequence_number), PicselloWeb.Helpers)

      assert %{
               whcc_order: %{
                 orders: [%{whcc_processing: nil}, %{whcc_processing: %{status: "Accepted"}}]
               }
             } = Repo.reload!(order)
    end

    test "works with shipping updates too", %{order: order, entry_id: entry_id} do
      insert(:email_preset, type: :gallery, state: :gallery_shipping_to_client)
      insert(:email_preset, type: :gallery, state: :gallery_shipping_to_photographer)

      order =
        order
        |> Order.whcc_order_changeset(
          build(:whcc_order_created,
            entry_id: entry_id,
            orders: build_list(2, :whcc_order_created_order)
          )
        )
        |> Repo.update!()

      Picsello.PhotoStorageMock
      |> Mox.stub(:get, fn _ -> {:error, nil} end)
      |> Mox.stub(:path_to_url, & &1)

      assert %{
               whcc_order: %{
                 entry_id: entry_id,
                 orders: [%{}, %{whcc_processing: nil, sequence_number: sequence_number}]
               }
             } = order

      Orders.update_whcc_order(processing_event(entry_id, sequence_number), PicselloWeb.Helpers)

      assert %{
               whcc_order: %{
                 orders: [%{whcc_tracking: nil}, %{whcc_tracking: %{event: "Shipped"}}]
               }
             } = Repo.reload!(order)

      assert_receive {:delivered_email, %{to: [email: "customer@example.com"]} = email}

      assert %{
               "button" => %{
                 text: "Track shipping",
                 url: "http://www.fedex.com/Tracking?tracknumbers=512376671311227"
               }
             } = email |> email_substitutions()

      assert_receive {:delivered_email, %{to: [nil: "photographer@example.com"]} = email}

      assert %{
               "button" => %{
                 text: "Track shipping",
                 url: "http://www.fedex.com/Tracking?tracknumbers=512376671311227"
               }
             } = email |> email_substitutions()
    end
  end
end
