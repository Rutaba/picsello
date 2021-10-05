defmodule Picsello.WelcomePageTest do
  use Picsello.FeatureCase, async: true

  setup %{session: session} do
    user = insert(:user, %{name: "Morty Smith"}) |> onboard!
    session |> sign_in(user)
    []
  end

  feature "user sees home page", %{session: session} do
    session
    |> assert_has(css("h1", text: ", Morty!"))
    |> assert_has(css("header", text: "MS"))
    |> assert_path("/home")
  end

  feature "user navigates to leads from navbar", %{session: session} do
    session
    |> click(css("nav a", text: "Leads"))
    |> assert_path(Routes.job_path(PicselloWeb.Endpoint, :leads))
  end
end
