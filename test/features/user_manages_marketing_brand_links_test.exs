defmodule Picsello.UserManagesMarketingBrandLinksTest do
  use Picsello.FeatureCase, async: false

  setup :onboarded
  setup :authenticated

  @website_field text_field("organization_profile_website")
  @website_login_field text_field("organization_profile_website_login")

  feature "sees missing link for website login", %{session: session} do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Marketing"))
    |> find(css("[data-testid='marketing-links']:nth-child(2)"), fn card ->
      card
      |> assert_has(css("h4", text: "Manage Website"))
      |> assert_has(css("[role='status']", text: "Missing link"))
    end)
  end

  feature "sees missing link for website", %{session: session} do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Marketing"))
    |> find(css("[data-testid='marketing-links']:first-child"), fn card ->
      card
      |> assert_has(css("h4", text: "Website"))
      |> assert_has(css("[role='status']", text: "Missing link"))
    end)
  end

  feature "views external brand link", %{session: session} do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Marketing"))
    |> find(css("[data-testid='marketing-links']:last-child"), fn card ->
      card
      |> assert_has(css("h4", text: "Pinterest"))
      |> click(link("Open"))
    end)
  end

  feature "views external next up card", %{session: session} do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Marketing"))
    |> find(css("[data-testid='marketing-attention-item']:last-child"), fn card ->
      card
      |> assert_has(css("h3", text: "Marketing tip: SEO"))
      |> click(link("Check out our blog"))
    end)
  end

  feature "goes to public profile settings", %{session: session} do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Marketing"))
    |> assert_has(
      css("[data-testid='marketing-attention-item']:first-child",
        text: "Review your Public Profile"
      )
    )
    |> click(button("Take me to settings"))
    |> assert_path("/profile/settings")
  end

  feature "edits website link", %{session: session} do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Marketing"))
    |> find(css("[data-testid='marketing-links']:first-child"), fn card ->
      card
      |> click(button("Edit"))
    end)
    |> click(css("#clear-website"))
    |> fill_in(@website_field, with: "inval!d.com")
    |> assert_has(css(".invalid-feedback", text: "Website URL is invalid"))
    |> fill_in(@website_field, with: "example.com")
    |> click(button("Save"))
    |> assert_flash(:success, text: "Link updated")
    |> find(css("[data-testid='marketing-links']:first-child"), fn card ->
      card
      |> refute_has(css("[role='status']", text: "Missing link"))
    end)
  end

  feature "edits website login link", %{session: session} do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Marketing"))
    |> find(css("[data-testid='marketing-links']:nth-child(2)"), fn card ->
      card
      |> click(button("Edit"))
    end)
    |> fill_in(@website_login_field,
      with: "inval!d.com"
    )
    |> assert_has(css(".invalid-feedback", text: "Website URL is invalid"))
    |> fill_in(@website_login_field, with: "example.com/wp-admin")
    |> click(button("Save"))
    |> assert_flash(:success, text: "Link updated")
    |> find(css("[data-testid='marketing-links']:nth-child(2)"), fn card ->
      card
      |> refute_has(css("[role='status']", text: "Missing link"))
    end)
  end
end
