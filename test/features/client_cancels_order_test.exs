defmodule Picsello.ClientCancelsOrderTest do
  use Picsello.FeatureCase, async: true
  import Money.Sigils

  setup do
    gallery =
      insert(:gallery,
        job: insert(:lead, package: insert(:package, download_each_price: ~M[3500]USD))
      )

    gallery_digital_pricing =
      insert(:gallery_digital_pricing, %{gallery: gallery, download_count: 0})

    photo_ids = insert_photo(%{gallery: gallery, total_photos: 3})
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)

    test_pid = self()

    Picsello.MockPayments
    |> Mox.stub(:create_session, fn params, _opts ->
      send(test_pid, {:create_session, params})

      {:ok, build(:stripe_session, url: "test_url")}
    end)
    |> Mox.stub(:expire_session, fn _id, _opts ->
      {:ok,
       build(:stripe_session,
         status: "expired",
         payment_intent: build(:stripe_payment_intent, status: "requires_payment_method")
       )}
    end)
    |> Mox.stub(:retrieve_payment_intent, fn _id, _opts ->
      {:ok, build(:stripe_payment_intent, status: "canceled")}
    end)

    [gallery: gallery, photo_ids: photo_ids, gallery_digital_pricing: gallery_digital_pricing]
  end

  setup :authenticated_gallery_client

  test "cancel from stripe, change order, go back to stripe", %{
    session: session,
    photo_ids: photo_ids
  } do
    session
    |> click(css("a", text: "View Gallery"))
    |> click(css("#img-#{List.first(photo_ids)}"))
    |> assert_text("Select an option")
    |> within_modal(&click(&1, button("Add to cart")))
    |> click(css("#img-#{List.last(photo_ids)}"))
    |> click(css("[phx-click='next']"))
    |> assert_text("Select an option")
    |> within_modal(&click(&1, button("Add to cart")))
    |> click(css("[phx-click='close']"))
    |> click(css("p", text: "Added!"))
    |> click(link("cart"))
    |> click(link("Continue"))
    |> fill_in(text_field("Email"), with: "zach@example.com")
    |> fill_in(text_field("Name"), with: "Zach")
    |> wait_for_enabled_submit_button()
    |> click(button("Check out with Stripe"))

    # assert [%{errors: []}] = run_jobs()
    # assert_receive {:create_session, %{cancel_url: cancel_url}}
    #
    # session
    # # |> visit(cancel_url)
    # |> assert_has(css("*[data-testid^='digital-']", count: 2))
    # |> click(button("Delete", count: 2, at: 0))
    # |> click(link("Continue"))
    # |> wait_for_enabled_submit_button()
    # |> click(button("Check out with Stripe"))
    #
    # assert [%{errors: []}, %{errors: []}] = run_jobs()
    #
    # assert_receive {:create_session, _params}
  end
end
