defmodule Picsello.ClientCancelsOrderTest do
  use Picsello.FeatureCase, async: true
  import Picsello.TestSupport.ClientGallery, only: [click_photo: 2]
  import Money.Sigils

  setup do
    gallery =
      insert(:gallery,
        job: insert(:lead, package: insert(:package, download_each_price: ~M[2500]USD))
      )

    insert_list(2, :photo, gallery: gallery)

    test_pid = self()

    Picsello.MockPayments
    |> Mox.stub(:create_session, fn params, _opts ->
      send(test_pid, {:create_session, params})
      {:ok, build(:stripe_session)}
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

    [gallery: gallery]
  end

  setup :authenticated_gallery_client

  def add_digital(session, index) do
    session
    |> click_photo(index)
    |> assert_text("Select an option")
    |> within_modal(&click(&1, button("Add to cart")))
  end

  test "cancel from stripe, change order, go back to stripe", %{session: session} do
    session
    |> click(link("View Gallery"))
    |> add_digital(1)
    |> add_digital(2)
    |> click(css("p", text: "Added!"))
    |> click(link("cart"))
    |> click(link("Continue"))
    |> fill_in(text_field("Email"), with: "zach@example.com")
    |> fill_in(text_field("Name"), with: "Zach")
    |> wait_for_enabled_submit_button()
    |> click(button("Check out with Stripe"))

    assert [%{errors: []}] = run_jobs()

    assert_receive {:create_session, %{cancel_url: cancel_url}}

    session
    |> visit(cancel_url)
    |> find(css("*[data-testid^='digital-']", count: 2, at: 0), &click(&1, button("Delete")))
    |> click(link("Continue"))
    |> wait_for_enabled_submit_button()
    |> click(button("Check out with Stripe"))

    assert [%{errors: []}, %{errors: []}] = run_jobs()

    assert_receive {:create_session, _params}
  end
end
