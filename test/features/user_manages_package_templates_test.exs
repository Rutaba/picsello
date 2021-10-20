defmodule Picsello.UserManagesPackageTemplatesTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  feature "navigate", %{session: session} do
    session
    |> click(link("Settings"))
    |> click(link("Package Templates"))
    |> assert_text("You don’t have any packages")
    |> assert_has(link("Add a package"))
  end

  feature "view list", %{session: session, user: user} do
    insert(:package_template, user: user, name: "Deluxe Template", download_count: 5)

    session
    |> click(link("Settings"))
    |> click(link("Package Templates"))
    |> assert_text("Deluxe Template")
    |> assert_has(definition("Downloadable photos", text: "5"))
  end
end
