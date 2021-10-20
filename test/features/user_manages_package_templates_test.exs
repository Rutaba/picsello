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
end
