defmodule Picsello.ClientBuysGreetingCardTest do
  use Picsello.FeatureCase, async: true

  alias Picsello.{Repo, Accounts.User}

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery
  setup %{user: user} do
    user = user |> User.assign_stripe_customer_changeset("cus_123") |> Repo.update!()

    Mox.stub(Picsello.MockPayments, :retrieve_customer, fn "cus_123", _ ->
      {:ok, %Stripe.Customer{invoice_settings: %{default_payment_method: "pm_12345"}}}
    end)

    [user: user]
  end

  setup do
    Picsello.Test.WHCCCatalog.sync_catalog()
  end

  setup %{gallery: gallery} do
    gallery |> Ecto.assoc(:photographer) |> Repo.one!() |> Map.put(:onboarding, nil) |> onboard!()
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)
    [photo | _] = insert_list(10, :photo, gallery: gallery)
    photo_ids = insert_photo(%{gallery: gallery, total_photos: 5})

    for category <- Repo.all(Picsello.Category) do
      insert(:gallery_product, category: category, gallery: gallery, preview_photo: photo)
    end

    :ok
    [photo_ids: photo_ids]
  end

  def click_filter_option(session, label_text, options \\ []) do
    options = Keyword.put_new(options, :visible, false)

    session
    |> find(css("label", count: :any, text: label_text), fn labels ->
      filter_label(labels, session, options, label_text)
    end)
  end

  def filter_label(labels, session, options, label_text) do
    labels
    |> Enum.find_value(fn label ->
      case Element.attr(label, "for") do
        <<_::binary-size(1)>> <> _ = id ->
          has?(session, css("input[type=checkbox]##{id}", options))

        _ ->
          has?(label, css("input[type=checkbox]", options))
      end && label
    end)
    |> case do
      nil -> "No labeled with text #{label_text} for a #{inspect(options)} checkbox"
      label -> Element.click(label)
    end
  end

  feature "filter designs", %{session: session, photo_ids: photo_ids, gallery: gallery} do
    session
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> click(css("a", text: "View Gallery"))
    |> click(css("#img-#{List.first(photo_ids)}"))
    |> within_modal(fn modal ->
      modal
      |> assert_text("Select an option")
      |> click(testid("product_option", op: "^=", text: "Press Printed Cards"))
    end)
    |> assert_has(css("h1", text: "Choose occasion"))
    |> click(link("holiday"))
    |> assert_has(css("h1", text: "Holiday"))
    |> assert_text("Showing 5 of 5 designs")
    |> click(button("Foil"))
    |> click_filter_option("Has Foil", selected: false)
    |> assert_has(testid("pills", text: "Has Foil"))
    |> click_filter_option("Has Foil", selected: true)
    |> click(button("Orientation"))
    |> click_filter_option("Landscape", selected: false)
    |> assert_has(testid("pills", text: "Landscape"))
    |> click(button("Type"))
    |> click_filter_option("New")
    |> assert_has(testid("pills", text: "Landscape\nNew", visible: true))
    |> assert_text("Showing 1 of 5 designs")
    |> find(testid("pills", visible: true), fn pills ->
      pills
      |> assert_has(css("label", count: 3))
      |> click_filter_option("Landscape")
      |> assert_has(css("label", count: 2))
    end)
    |> click(button("Type"))
    |> assert_has(checkbox("new", visible: false, selected: true))
    |> find(testid("pills", visible: true), &click_filter_option(&1, "New"))
    |> assert_has(checkbox("new", visible: false, selected: false))
  end
end
