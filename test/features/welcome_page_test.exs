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

  feature "user navigates to leads from sidebar", %{session: session} do
    session
    |> click(css("#hamburger-menu"))
    |> assert_has(css("#hamburger-menu nav a[title='Leads']:not(.font-bold)"))
    |> click(css("#hamburger-menu nav a", text: "Leads"))
    |> assert_path(Routes.job_path(PicselloWeb.Endpoint, :leads))
    |> click(css("#hamburger-menu"))
    |> assert_has(css("nav a.font-bold", text: "Lead"))
  end

  feature "user goes to profile page from initials menu", %{session: session} do
    session
    |> click(css("div[title='Morty Smith']"))
    |> click(link("Profile"))
    |> assert_path(Routes.user_settings_path(PicselloWeb.Endpoint, :edit))
  end

  feature "user logs out from initials menu", %{session: session} do
    session
    |> click(css("div[title='Morty Smith']"))
    |> click(button("Logout"))
    |> assert_path("/")
    |> assert_flash(:info, text: "Logged out successfully")
  end
end
