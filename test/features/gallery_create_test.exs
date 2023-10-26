defmodule Picsello.GalleryCreateTest do
  @moduledoc false
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup %{session: session, user: user} do
    insert(:client,
      user: user,
      name: "Elizabeth Taylor",
      email: "taylor@example.com",
    )

    [session: session]
  end

  feature "creates gallery from dashboard", %{
    session: session
  } do
    session
    |> click(button("Actions"))
    |> click(button("Create gallery"))
    |> click(button("Next", count: 2, at: 0))
    |> fill_in(text_field("search_phrase"), with: "Eliza")
    |> assert_has(css("#search_results"))
    |> send_keys([:down_arrow])
    |> send_keys([:enter])
    |> click(css("label", text: "Wedding"))
    |> find(select("# of Shoots"), &click(&1, option("2")))
    |> wait_for_enabled_submit_button(text: "Next")
    |> within_modal(&click(&1, button("Next")))
    |> scroll_into_view(testid("print"))
    |> click(radio_button("Gallery does not include Print Credits"))
    |> scroll_into_view(css("#download_is_buy_all"))
    |> within_modal(&click(&1, button("Save")))
    |> assert_flash(:success, text: "Gallery created—")
    |> assert_url_contains("galleries")
  end
end
