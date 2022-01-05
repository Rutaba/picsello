defmodule Picsello.UserOnboardsTest do
  use Picsello.FeatureCase, async: true

  alias Picsello.{Accounts.User, Repo}

  setup :authenticated

  setup do
    insert(:cost_of_living_adjustment)
    insert(:package_tier)
    insert(:package_base_price)
    :ok
  end

  @onboarding_path Routes.onboarding_path(PicselloWeb.Endpoint, :index)
  @phone_field text_field("user_onboarding_phone")
  @photographer_years_field text_field("user_onboarding_photographer_years")
  @second_color_field css("li.aspect-h-1.aspect-w-1:nth-child(2)")
  @website_field text_field("user_organization_profile_website")

  def fill_in_step(session, 2) do
    session
    |> fill_in(@photographer_years_field, with: "5")
    |> fill_in(@phone_field, with: "1234567890")
    |> click(option("OK"))
  end

  feature "user onboards", %{session: session, user: user} do
    user = Repo.preload(user, :organization)
    org_name_field = text_field("user_organization_name")
    home_path = Routes.home_path(PicselloWeb.Endpoint, :index)

    session
    |> assert_path(@onboarding_path)
    |> assert_disabled_submit()
    |> assert_value(org_name_field, user.organization.name)
    |> fill_in(org_name_field, with: "")
    |> assert_has(css("span.invalid-feedback", text: "Photography business name can't be blank"))
    |> fill_in(org_name_field, with: "Photogenious")
    |> fill_in(@photographer_years_field, with: "5")
    |> click(option("OK"))
    |> fill_in(@phone_field, with: "123")
    |> assert_disabled_submit()
    |> fill_in(@phone_field, with: "1234567890")
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> assert_disabled_submit()
    |> click(css("label", text: "Portrait"))
    |> click(css("label", text: "Event"))
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> assert_disabled_submit()
    |> click(@second_color_field)
    |> fill_in(@website_field, with: "inval!d.com")
    |> assert_disabled_submit()
    |> fill_in(@website_field, with: "example.com")
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> assert_disabled_submit()
    |> click(css("label", text: "Shootproof"))
    |> click(css("label", text: "Session"))
    |> click(css("button[type='submit']", text: "Finish"))
    |> assert_path(home_path)

    user =
      user
      |> Repo.reload()
      |> Repo.preload(organization: :package_templates)

    second_color = Picsello.Profiles.colors() |> tl |> hd

    assert %User{
             onboarding: %{
               schedule: :full_time,
               phone: "(123) 456-7890",
               photographer_years: 5,
               switching_from_softwares: [:shootproof, :session],
               completed_at: %DateTime{}
             },
             organization: %{
               name: "Photogenious",
               package_templates: [%{base_price: %Money{amount: 100}}],
               profile: %{
                 website: "example.com",
                 no_website: false,
                 color: ^second_color,
                 job_types: ~w(event portrait)
               }
             }
           } = user
  end

  feature "user goes back while onboarding", %{session: session, user: user} do
    session
    |> assert_path(@onboarding_path)
    |> assert_disabled_submit()
    |> fill_in_step(2)
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> assert_text("What types")
    |> click(button("Back"))
    |> assert_has(@photographer_years_field)

    assert %User{
             onboarding: %{phone: "(123) 456-7890"},
             organization: %{profile: %{job_types: nil}}
           } = user |> Repo.reload() |> Repo.preload(:organization)
  end

  feature "user onboards without website", %{session: session, user: user} do
    session
    |> assert_path(@onboarding_path)
    |> fill_in_step(2)
    |> click(button("Next"))
    |> click(css("label", text: "Portrait"))
    |> click(button("Next"))
    |> click(@second_color_field)
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
             organization: %{
               profile: %{
                 website: nil,
                 no_website: true
               }
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
