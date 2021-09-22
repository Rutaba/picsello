defmodule Picsello.UserOnboardsTest do
  use Picsello.FeatureCase, async: true

  alias PicselloWeb.Router.Helpers, as: Routes
  alias Picsello.Accounts.User

  setup :authenticated

  feature "user onboards", %{session: session, user: user} do
    org_name_field = text_field("user_organization_name")
    phone_field = text_field("user_onboarding_phone")
    website_field = text_field("user_onboarding_website")

    session
    |> assert_path(Routes.onboarding_path(PicselloWeb.Endpoint, :index))
    |> assert_value(org_name_field, "#{user.name} Photography")
    |> fill_in(org_name_field, with: "Photogenious")
    |> fill_in(website_field, with: "inval!d.com")
    |> fill_in(phone_field, with: "123")
    |> assert_disabled_submit(count: 2)
    |> fill_in(website_field, with: "example.com")
    |> fill_in(phone_field, with: "1234567890")
    |> click(checkbox("user_onboarding_no_website"))
    |> click(option("Full-time"))
    |> wait_for_enabled_submit_button(count: 2)
    |> take_screenshot()
    |> click(button("Next"))
    |> assert_path(Routes.home_path(PicselloWeb.Endpoint, :index))

    user =
      user
      |> Picsello.Repo.reload()
      |> Picsello.Repo.preload(:organization)

    assert %User{
             onboarding: %{
               schedule: :full_time,
               website: "example.com",
               phone: "(123) 456-7890",
               no_website: true
             }
           } = user

    assert %User{organization: %{name: "Photogenious"}} = user
  end

  feature "user is redirected to onboarding", %{session: session} do
    session
    |> assert_path(Routes.onboarding_path(PicselloWeb.Endpoint, :index))
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :jobs))
    |> assert_path(Routes.onboarding_path(PicselloWeb.Endpoint, :index))
    |> assert_text("Tell us more about yourself")
  end
end
