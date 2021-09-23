defmodule Picsello.UserOnboardsTest do
  use Picsello.FeatureCase, async: true

  alias PicselloWeb.Router.Helpers, as: Routes
  alias Picsello.{Accounts.User, Repo}

  setup :authenticated

  @website_field text_field("user_onboarding_website")
  @onboarding_path Routes.onboarding_path(PicselloWeb.Endpoint, :index)
  @home_path Routes.home_path(PicselloWeb.Endpoint, :index)
  @second_color_field css("li.aspect-h-1.aspect-w-1:nth-child(2)")
  @org_name_field text_field("user_organization_name")

  feature "user onboards", %{session: session, user: user} do
    phone_field = text_field("user_onboarding_phone")

    session
    |> assert_path(@onboarding_path)
    |> assert_value(@org_name_field, "#{user.name} Photography")
    |> fill_in(@org_name_field, with: "Photogenious")
    |> fill_in(@website_field, with: "inval!d.com")
    |> fill_in(phone_field, with: "123")
    |> assert_disabled_submit()
    |> fill_in(@website_field, with: "example.com")
    |> fill_in(phone_field, with: "1234567890")
    |> click(option("Full-time"))
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> click(link("previous"))
    |> assert_has(@org_name_field)
    |> click(button("Next"))
    |> click(@second_color_field)
    |> click(button("Next"))
    |> click(css("label", text: "Portrait"))
    |> click(css("label", text: "Event"))
    |> click(button("Next"))
    |> assert_path(@home_path)

    user =
      user
      |> Repo.reload()
      |> Repo.preload(:organization)

    second_color = User.Onboarding.colors() |> tl |> hd

    assert %User{
             onboarding: %{
               schedule: :full_time,
               website: "example.com",
               phone: "(123) 456-7890",
               no_website: false,
               color: ^second_color,
               job_types: ~w(event portrait)
             }
           } = user

    assert %User{organization: %{name: "Photogenious"}} = user
  end

  feature "user skips onboarding", %{session: session, user: user} do
    session
    |> assert_path(@onboarding_path)
    |> fill_in(@website_field, with: "inval!d.com")
    |> fill_in(@org_name_field, with: "best pictures")
    |> click(button("Skip"))
    |> assert_has(@second_color_field)

    assert %User{organization: %{name: "best pictures"}, onboarding: %{website: nil}} =
             user |> Repo.reload() |> Repo.preload(:organization)
  end

  feature "user onboards without website", %{session: session, user: user} do
    session
    |> assert_path(@onboarding_path)
    |> fill_in(@website_field, with: "example.com")
    |> click(checkbox("I don't have one"))
    |> assert_value(@website_field, "")
    |> assert_disabled(@website_field)
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))

    user =
      user
      |> Repo.reload()
      |> Repo.preload(:organization)

    assert %User{
             onboarding: %{
               website: nil,
               no_website: true
             }
           } = user
  end

  feature "user is redirected to onboarding", %{session: session} do
    session
    |> assert_path(@onboarding_path)
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :jobs))
    |> assert_path(@onboarding_path)
    |> assert_text("Tell us more about yourself")
  end
end
