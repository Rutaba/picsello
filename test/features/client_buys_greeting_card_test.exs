defmodule Picsello.ClientBuysGreetingCardTest do
  use Picsello.FeatureCase, async: true

  import Picsello.TestSupport.ClientGallery, only: [click_photo: 2]
  alias Picsello.Repo

  setup do
    Mox.verify_on_exit!()
    Picsello.Test.WHCCCatalog.sync_catalog()
    [gallery: insert(:gallery)]
  end

  setup %{gallery: gallery} do
    gallery |> Ecto.assoc(:photographer) |> Repo.one!() |> Map.put(:onboarding, nil) |> onboard!()

    [photo | _] = insert_list(10, :photo, gallery: gallery)

    for category <- Repo.all(Picsello.Category) do
      insert(:gallery_product, category: category, gallery: gallery, preview_photo: photo)
    end

    :ok
  end

  setup :authenticated_gallery_client

  def click_filter_option(session, label_text, options \\ []) do
    options = Keyword.put_new(options, :visible, false)

    session
    |> find(css("label", count: :any, text: label_text), fn labels ->
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
    end)
  end

  feature "filter designs", %{session: session} do
    session
    |> click(css("a", text: "View Gallery"))
    |> click_photo(1)
    |> within_modal(fn modal ->
      modal
      |> assert_text("Select an option")
      |> click(testid("product_option", op: "^=", text: "Press Printed Cards"))
    end)
    |> assert_has(css("h1", text: "Choose occasion"))
    |> click(link("holiday"))
    |> assert_has(css("h1", text: "Holiday"))
    |> assert_text("Showing 5 of 5 designs")
    |> click(button("Filters"))
    |> find(css("#filter-form", visible: true), fn form ->
      form
      |> click(button("Foil"))
      |> click_filter_option("Has Foil", selected: false)
      |> assert_has(testid("pills", text: "Has Foil"))
      |> click_filter_option("Has Foil", selected: true)
      |> click(button("Orientation"))
      |> click_filter_option("Landscape", selected: false)
      |> assert_has(testid("pills", text: "Landscape"))
      |> click(button("Type"))
      |> click_filter_option("New")
    end)
    |> click(button("Show results"))
    |> assert_has(testid("pills", text: "Landscape\nNew", visible: true))
    |> assert_text("Showing 1 of 5 designs")
    |> find(testid("pills", visible: true), fn pills ->
      pills
      |> assert_has(css("label", count: 2))
      |> click_filter_option("Landscape")
      |> assert_has(css("label", count: 1))
    end)
    |> assert_text("Showing 5 of 5 designs")
    |> click(button("Filters"))
    |> find(css("#filter-form", visible: true), fn form ->
      form
      |> click(button("Type"))
      |> assert_has(checkbox("new", visible: false, selected: true))
      |> find(testid("pills", visible: true), &click_filter_option(&1, "New"))
      |> assert_has(checkbox("new", visible: false, selected: false))
    end)
  end
end
