defmodule Picsello.OrderTransactionsTest do
  use Picsello.FeatureCase, async: true
  import Money.Sigils
  alias Picsello.{Job, Repo}

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup %{user: user, gallery: gallery} do
    order =
      insert(:order,
        gallery: gallery,
        placed_at: DateTime.utc_now(),
        delivery_info: %Picsello.Cart.DeliveryInfo{
          address: %Picsello.Cart.DeliveryInfo.Address{
            addr1: "661 w lake st",
            city: "Chicago",
            state: "IL",
            zip: "60661"
          }
        },
        products:
          build_list(1, :cart_product,
            whcc_product: insert(:product),
            editor_id: "editor_id"
          ),
        whcc_order:
          build(:whcc_order_created,
            entry_id: "123",
            orders:
              build_list(1, :whcc_order_created_order,
                sequence_number: 69,
                editor_id: "editor_id",
                total: ~M[500]USD
              )
          )
      )

    insert(:intent, order: order)
    insert(:digital, order: order, price: ~M[200]USD)

    order_number = Picsello.Cart.OrderNumber.to_number(order.id)
    Ecto.Changeset.change(order, %{number: order_number}) |> Repo.update()

    [user: user, order: order, order_number: order_number]
  end

  feature "Transactions view order test", %{order: %{gallery: %{job: job}}, session: session} do
    session
    |> visit("/jobs/#{job.id}")
    |> click(button("View orders"))
    |> assert_has(css("a[href='/jobs/#{job.id}']", count: 2))
    |> click(css("a[href='/jobs/#{job.id}'] svg"))
    |> assert_url_contains("/jobs/#{job.id}")
  end

  feature "Transactions header test", %{order: %{gallery: %{job: job}}, session: session} do
    session
    |> visit("/jobs/#{job.id}/transactions")
    |> assert_has(css("a[href='/jobs']", text: "Jobs"))
    |> assert_has(css("a[href='/jobs/#{job.id}']", text: Job.name(job)))
    |> assert_has(css("span", text: Job.name(job), count: 2))
    |> click(button("Go to Stripe"))
    |> assert_url_contains("payments")
  end

  feature "Transactions table test", %{
    order: %{gallery: %{job: job}} = order,
    order_number: order_number,
    session: session
  } do
    session
    |> visit("/jobs/#{job.id}/transactions")
    |> assert_has(testid("orders", count: 1))
    |> assert_has(css("*[phx-click='order-detail']", text: "Product order"))
    |> assert_has(css("*[phx-click='order-detail']", text: "View details"))
    |> assert_text("$557")
    |> assert_text(Calendar.strftime(order.placed_at, "%m/%d/%Y"))
    |> click(css("*[phx-click='order-detail']", text: "View details"))
    |> assert_url_contains("/jobs/#{job.id}/transactions/#{order_number}")
  end

  feature "order detail page shipping address test", %{
    order: %{gallery: %{id: id, job: job}},
    order_number: order_number,
    session: session
  } do
    session
    |> visit("/jobs/#{job.id}/transactions/#{order_number}")
    |> assert_has(css("a[href='/jobs/#{job.id}/transactions']", count: 1))
    |> assert_text("order has been shipped to")
    |> assert_text("661 w lake st")
    |> assert_text("Chicago, IL 60661")
    |> click(css("#view_gallery"))
    |> assert_url_contains("/galleries/#{id}")
  end

  feature "order detail page summary test", %{
    order: %{gallery: %{job: job}},
    order_number: order_number,
    session: session
  } do
    session
    |> visit("/jobs/#{job.id}/transactions/#{order_number}")
    |> assert_text("Transaction Summary")
    |> assert_text("Use your Stripe dashboard")
    |> assert_text("Products (1)")
    |> assert_text("$555.00")
    |> assert_text("Shipping & handling")
    |> assert_text("Included")
    |> assert_text("Digital downloads (1)")
    |> assert_text("$2.00")
    |> assert_text("Subtotal")
    |> assert_text("$557.00")
    |> assert_text("Total")
    |> assert_text("$557.00")
    |> click(button("Go to Stripe"))
    |> assert_url_contains("payments")
  end

  feature "order detail test", %{
    order: %{gallery: %{job: job}},
    order_number: order_number,
    session: session
  } do
    session
    |> visit("/jobs/#{job.id}/transactions/#{order_number}")
    |> assert_text("Order details")
    |> assert_text("Order number: #{order_number}")
    |> assert_text("20×30 polo")
    |> assert_text("Quantity: 1")
    |> assert_text("We’ll provide tracking info once your item ships")
    |> assert_text("Digital download")
    |> assert_has(css("img[src$='/phoenix.png']"))
  end
end