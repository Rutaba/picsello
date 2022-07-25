defmodule Picsello.UserManagesMarketingBrandLinksTest do
  use Picsello.FeatureCase, async: false

  setup do
    user = %{
      user:
        insert(:user,
          organization: %{
            name: "Mary Jane Photography",
            slug: "mary-jane-photos",
            profile: %{
              job_types: ~w(portrait event)
            }
          }
        )
        |> onboard!
    }

    insert(:brand_link, user)

    user
  end

  setup :authenticated

  feature "view with no brand link added", %{session: session} do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Marketing"))
    |> assert_text("Looks like you don’t have any links")
    # iPhone 8+
    |> resize_window(414, 736)
    |> assert_text("Add links to your web platforms")
  end

  feature "edit and activate brand link with disabled delete button", %{session: session} do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Marketing"))
    |> click(button("Manage links"))
    |> fill_in(css("#brand-link_link"), with: "https://xyz.com")
    |> force_simulate_click(testid("active?"))
    |> force_simulate_click(testid("use_publicly?"))
    |> force_simulate_click(testid("show_on_profile?"))
    |> assert_has(css("#delete-link", count: 0))
    |> click(css("#save"))
    |> assert_text("Add links to your web platforms")
    |> find(css("[data-testid='marketing-links']:first-child"), fn card ->
      card
      |> assert_has(css("h4", text: "Website"))
      |> assert_has(css("a", text: "Open"))
      |> assert_has(css("button", text: "Edit"))
    end)
  end

  feature "edit and activate brand link with disabled delete button for mobile", %{
    session: session
  } do
    session
    # iPhone 8+
    |> resize_window(414, 736)
    |> click(css("#hamburger-menu"))
    |> click(link("Marketing"))
    |> click(button("Manage links"))
    |> click(css("#save_mobile"))
    |> click(css("#side-nave > div:first-child"))
    |> fill_in(css("#brand-link_link"), with: "https://xyz.com")
    |> force_simulate_click(testid("active?"))
    |> force_simulate_click(testid("use_publicly?"))
    |> force_simulate_click(testid("show_on_profile?"))
    |> assert_has(css("#delete-link", count: 0))
    |> click(css("#save_mobile"))
    |> assert_has(css("#side-nave div.grid-item", count: 10))
    |> click(css("#live_modal-1-0 button"))
    |> find(css("#marketing-links div:first-child"))
  end

  feature "add and delete custom link", %{session: session} do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Marketing"))
    |> click(button("Manage links"))
    |> click(css("span", text: "Add new link"))
    |> fill_in(css("#brand-link_link"), with: "https://xyz.com")
    |> force_simulate_click(testid("use_publicly?"))
    |> force_simulate_click(testid("show_on_profile?"))
    |> click(css("#delete-link"))
    |> click(css("span", text: "Add new link"))
    |> fill_in(css("#brand-link_link"), with: "http://abc.com")
    |> force_simulate_click(testid("use_publicly?"))
    |> force_simulate_click(testid("show_on_profile?"))
    |> click(css("#save"))
    |> assert_text("Add links to your web platforms")
    |> click(testid("marketing-links", count: 1))
    |> find(css("#marketing-links div:first-child"))
  end

  feature "view and edit button test", %{session: session} do
    session
    |> click(css("#hamburger-menu"))
    |> click(link("Marketing"))
    |> click(button("Manage links"))
    |> fill_in(css("#brand-link_link"), with: "https://xyz.com")
    |> force_simulate_click(testid("active?"))
    |> assert_has(css("#delete-link", count: 0))
    |> click(css("#save"))
    |> find(css("[data-testid='marketing-links']:first-child"), fn card ->
      card
      |> assert_has(css("a[href='https://xyz.com']", text: "Open"))
      |> click(css("button", text: "Edit"))
    end)
    |> click(css("#save"))
    |> assert_text("Add links to your web platforms")
    |> click(testid("marketing-links", count: 1))
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
end
