defmodule Picsello.PhotographerViewOrdersTest do
  use Picsello.FeatureCase, async: true
  import Money.Sigils

  setup :onboarded
  setup :authenticated

  feature "photograper view no gallery and no order test", %{
    session: session,
    user: user
  } do
    organization = insert(:organization, user: user)
    client = insert(:client, organization: organization)
    package = insert(:package, organization: organization, download_each_price: ~M[2500]USD)
    job = insert(:lead, type: "wedding", client: client, package: package) |> promote_to_job()

    session
    |> visit("/jobs/#{job.id}/")
    |> find(
      testid("card-Gallery",
        text: "You don't have galleries for this job setup. Create one now!"
      ),
      &click(&1, button("Start Setup"))
    )
    |> assert_has(css("h1", text: "Set Up Your Gallery"))
    |> click(button("Get Started", count: 2, at: 0))
    |> visit("/jobs/#{job.id}/")
    |> find(testid("card-buttons"))
  end

  setup :authenticated_gallery

  feature "photograper view order", %{session: session, gallery: %{job: job} = gallery} do
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
              editor_ids: ["editor_id"],
              total: ~M[500]USD
            )
        )
    )

    session
    |> visit("/jobs/#{job.id}/")
    |> find(testid("card-buttons"))
    |> click(button("Actions"))
    |> assert_has(button("View orders"))
  end
end
