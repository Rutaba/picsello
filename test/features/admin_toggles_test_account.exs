defmodule Picsello.AdminTogglesTestAccount do
  use Picsello.FeatureCase, async: false

  setup :onboarded
  setup :authenticated

  def visit_and_search(session, user) do
    session
    |> visit("/admin")
    |> click(link("Manage Users"))
    |> assert_text("Find user to edit")
    |> click(css("#search_phrase_input"))
    |> fill_in(text_field("search_phrase_input"), with: user.email)
    |> send_keys([:enter])
    |> assert_text("Mary Jane")
  end

  feature "User is defaulted to is_test_account: false", %{session: session, user: user} do
    session
    |> visit_and_search(user)
    |> find(checkbox("Is user a test account? (exclude from analytics)"), fn checkbox ->
      refute Element.selected?(checkbox)
    end)
  end

  feature "User selects test account", %{session: session, user: user} do
    session
    |> visit_and_search(user)
    |> click(checkbox("Is user a test account? (exclude from analytics)"))
    |> fill_in(text_field("search_phrase_input"), with: "user.email")
    |> fill_in(text_field("search_phrase_input"), with: user.email)
    |> send_keys([:enter])
    |> find(checkbox("Is user a test account? (exclude from analytics)"), fn checkbox ->
      assert Element.selected?(checkbox)
    end)
  end
end
