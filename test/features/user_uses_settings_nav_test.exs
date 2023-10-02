defmodule Picsello.UserUsesSettingsNavTest do
  @moduledoc false
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  feature "user views settings and uses settings nav", %{session: session} do
    session
    |> click(css("#settings-nav"))
    |> click(css("[title='Packages']"))
    |> find(
      testid("settings-nav"),
      &(&1
        |> assert_has(css("li", count: 10)))
    )
    |> assert_text("Packages")
    |> assert_text("Contracts")
    |> assert_text("Questionnaires")
    |> assert_text("Calendar")
    |> assert_text("Gallery")
    |> assert_text("Finances")
    |> assert_text("Brand")
    |> assert_text("Public Profile")
    |> assert_text("Account")
    |> assert_has(testid("settings-heading", text: "Packages"))
    |> click(css("[title='contracts_index']"))
    |> assert_has(testid("settings-heading", text: "Contracts"))
    |> click(css("[title='questionnaires_index']"))
    |> assert_has(testid("settings-heading", text: "Questionnaires"))
    |> click(css("[title='calendar_settings']"))
    |> assert_has(testid("settings-heading", text: "Calendar"))
    |> click(css("[title='gallery_global_settings_index']"))
    |> assert_has(testid("settings-heading", text: "Gallery"))
    |> click(css("[title='finance_settings']"))
    |> assert_has(testid("settings-heading", text: "Finances"))
    |> click(css("[title='brand_settings']"))
    |> assert_has(testid("settings-heading", text: "Brand"))
    |> click(css("[title='profile_settings']"))
    |> assert_has(testid("settings-heading", text: "Public Profile"))
    |> click(css("[title='user_settings']"))
    |> assert_has(testid("settings-heading", text: "Account"))
  end
end
