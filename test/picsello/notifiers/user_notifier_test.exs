defmodule Picsello.Notifiers.UserNotifierTest do
  use Picsello.DataCase, async: true
  alias Picsello.{Cart, Cart.Order, Notifiers.UserNotifier}
  import Money.Sigils

  setup do
    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)
    :ok
  end

  def deliver_order_confirmation(order) do
    UserNotifier.deliver_order_confirmation(order, PicselloWeb.Helpers)
  end

  def template_variables(%{
        private: %{send_grid_template: %{dynamic_template_data: template_variables}}
      }),
      do: for({k, v} <- template_variables, into: %{}, do: {String.to_existing_atom(k), v})

  def insert_gallery(%{package: package}) do
    [gallery: insert(:gallery, job: insert(:lead, package: package))]
  end

  def insert_gallery(_) do
    insert_gallery(%{package: insert(:package)})
  end

  def insert_order_and_gallery_client(%{gallery: gallery, products: products}) do
    gallery_digital_pricing =
      insert(:gallery_digital_pricing, %{
        gallery: gallery,
        email_list: [gallery.job.client.email],
        download_count: 0,
        print_credits: Money.new(0)
      })

    gallery =
      Map.put(
        gallery,
        :credits_available,
        gallery.job.client.email in gallery_digital_pricing.email_list
      )

    gallery_client =
      insert(:gallery_client, %{email: "testing@picsello.com", gallery_id: gallery.id})

    order =
      for product <- products, reduce: nil do
        _ ->
          Cart.place_product(product, gallery, gallery_client)
      end
      |> Repo.preload(
        [
          :products,
          :digitals,
          :invoice,
          :intent,
          gallery: [job: [:package, client: [organization: :user]]]
        ],
        force: true
      )

    [
      order:
        order
        |> Cart.add_default_shipping_to_products()
        |> then(&Map.put(order, :products, &1))
    ]
  end

  def add_whcc_order(%{order: order}) do
    [
      order:
        order
        |> Order.whcc_order_changeset(build(:whcc_order_created, total: ~M[500]USD))
        |> Repo.update!()
    ]
  end

  def shared_fields(order) do
    %{
      client_order_url:
        PicselloWeb.Router.Helpers.gallery_client_order_url(
          PicselloWeb.Endpoint,
          :show,
          order.gallery.client_link_hash,
          Order.number(order),
          pw: order.gallery.password,
          email: "testing@picsello.com"
        ),
      gallery_name: "Test Client Wedding",
      job_name: "Mary Jane Wedding",
      client_name: "Mary Jane",
      contains_product: true,
      products_quantity: 1
    }
  end

  describe "deliver_order_confirmation - order uses print credits" do
    setup do
      [
        package: insert(:package, print_credits: ~M[10000]USD),
        products: build_list(1, :cart_product)
      ]
    end

    setup [:insert_gallery, :insert_order_and_gallery_client, :add_whcc_order]

    setup %{order: order} do
      insert(:intent,
        order: order,
        amount: Cart.total_cost(order),
        application_fee_amount: ~M[500]USD
      )

      [order: Repo.preload(order, :intent, force: true)]
    end

    test "includes print_credit_{used,remaining}", %{order: order} do
      assert {:ok, email} = deliver_order_confirmation(order)

      assert order
             |> shared_fields()
             |> Map.merge(%{
               client_charge: ~M[56645]USD,
               photographer_payment: %Money{amount: 51_127, currency: :USD},
               print_cost: ~M[0]USD,
               total_costs: %Money{amount: -5518, currency: :USD},
               photographer_charge: %Money{amount: 0, currency: :USD},
               stripe_fee: %Money{amount: -1673, currency: :USD},
               positive_shipping: %Money{amount: 3845, currency: :USD},
               shipping: %Money{amount: -3845, currency: :USD},
               total_products_price: %Money{amount: 52_800, currency: :USD},
               print_credit_remaining: %Money{amount: 0, currency: :USD},
               print_credit_used: %Money{amount: 0, currency: :USD},
               print_credits_available: true
             }) ==
               template_variables(email)
    end
  end

  describe "deliver_order_confirmation - order uses print credits, photographer owes" do
    setup do
      [
        package: insert(:package, print_credits: ~M[60000]USD),
        products: build_list(1, :cart_product)
      ]
    end

    setup [:insert_gallery, :insert_order_and_gallery_client, :add_whcc_order]

    setup %{order: order} do
      insert(:invoice, order: order, amount_due: ~M[20000]USD)

      [order: Repo.preload(order, :invoice, force: true)]
    end

    test "includes photographer_charge", %{order: order} do
      assert {:ok, email} = deliver_order_confirmation(order)

      assert order
             |> shared_fields()
             |> Map.merge(%{
               client_charge: ~M[0]USD,
               print_cost: %Money{amount: 0, currency: :USD},
               shipping: %Money{amount: -3845, currency: :USD},
               positive_shipping: %Money{amount: 3845, currency: :USD},
               total_costs: %Money{amount: -3845, currency: :USD},
               total_products_price: %Money{amount: 52_800, currency: :USD},
               print_credit_remaining: %Money{amount: 0, currency: :USD},
               print_credit_used: %Money{amount: 0, currency: :USD},
               print_credits_available: true
             }) ==
               template_variables(email)
    end
  end

  describe "deliver_order_confirmation - only digitals" do
    setup do
      [
        package: insert(:package, print_credits: ~M[100]USD),
        products: build_list(1, :digital, price: ~M[1000]USD)
      ]
    end

    setup [:insert_gallery, :insert_order_and_gallery_client]

    setup %{order: order} do
      insert(:intent, order: order, amount: Cart.total_cost(order))

      [order: Repo.preload(order, :intent, force: true)]
    end

    test "no print fields", %{order: order} do
      assert {:ok, email} = deliver_order_confirmation(order)

      assert order
             |> shared_fields()
             |> Map.merge(%{
               client_charge: ~M[1000]USD,
               photographer_payment: ~M[941]USD,
               contains_digital: true,
               digital_credit_remaining: 0,
               digital_credit_used: %{},
               digital_quantity: "1",
               contains_product: false,
               photographer_charge: %Money{amount: 0, currency: :USD},
               positive_shipping: %Money{amount: 0, currency: :USD},
               shipping: %Money{amount: 0, currency: :USD},
               stripe_fee: %Money{amount: -59, currency: :USD},
               total_costs: %Money{amount: -59, currency: :USD},
               total_digitals_price: %Money{amount: 1000, currency: :USD},
               total_products_price: %Money{amount: 0, currency: :USD},
               products_quantity: 0,
               print_credit_remaining: %Money{amount: 0, currency: :USD},
               print_credit_used: %Money{amount: 0, currency: :USD},
               print_credits_available: true
             }) ==
               template_variables(email)
    end
  end
end
