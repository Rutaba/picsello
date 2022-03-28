defmodule Picsello.UserOnboardsTest do
  use Picsello.FeatureCase, async: true

  alias Picsello.{Accounts.User, Repo}

  setup :authenticated

  setup %{session: session} do
    insert(:cost_of_living_adjustment)
    insert(:package_tier)
    insert(:package_base_price, base_price: 300)
    subscription_plan = insert(:subscription_plan)
    [session: visit(session, "/"), subscription_plan: subscription_plan]
  end

  @onboarding_path Routes.onboarding_path(PicselloWeb.Endpoint, :index)
  @phone_field text_field("onboarding-step-2_onboarding_phone")
  @photographer_years_field text_field("onboarding-step-2_onboarding_photographer_years")
  @second_color_field css("li.aspect-h-1.aspect-w-1:nth-child(2)")
  @website_field text_field("onboarding-step-4_organization_profile_website")

  def fill_in_step(session, 2) do
    session
    |> fill_in(@photographer_years_field, with: "5")
    |> fill_in(@phone_field, with: "1234567890")
    |> click(option("OK"))
  end

  feature "user onboards", %{session: session, user: user, subscription_plan: subscription_plan} do
    user = Repo.preload(user, :organization)

    org_name_field = text_field("onboarding-step-2_organization_name")
    home_path = Routes.home_path(PicselloWeb.Endpoint, :index)

    test_pid = self()

    Picsello.MockPayments
    |> Mox.stub(:create_session, fn params, opts ->
      send(
        test_pid,
        {:checkout_linked, opts |> Enum.into(params)}
      )

      {:ok, "https://example.com/stripe-checkout"}
    end)
    |> Mox.stub(:retrieve_session, fn "{CHECKOUT_SESSION_ID}", _opts ->
      {:ok, %Stripe.Session{subscription: "sub_123"}}
    end)
    |> Mox.stub(:create_customer, fn %{}, _opts ->
      {:ok, %Stripe.Customer{id: "cus_123"}}
    end)
    |> Mox.stub(:retrieve_subscription, fn "sub_123", _opts ->
      {:ok,
       %Stripe.Subscription{
         id: "s1",
         status: "active",
         current_period_start: DateTime.utc_now() |> DateTime.to_unix(),
         current_period_end: DateTime.utc_now() |> DateTime.add(100) |> DateTime.to_unix(),
         plan: %{id: subscription_plan.stripe_price_id},
         customer: "cus_123"
       }}
    end)

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
    |> assert_has(css("input[name$='[website]']:not(.text-input-invalid:not(.phx-no-feedback))"))
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
    |> find(css("input:checked", count: 2, visible: false), fn inputs ->
      assert ~w[shootproof session] == Enum.map(inputs, &Element.value/1)
    end)
    |> click(css("label", text: "None"))
    |> assert_value(css("input:checked", count: 1, visible: false), "none")
    |> click(css("label", text: "Shootproof"))
    |> click(css("label", text: "Session"))
    |> find(css("input:checked", count: 2, visible: false), fn inputs ->
      assert ~w[shootproof session] == Enum.map(inputs, &Element.value/1)
    end)
    |> click(css("button[type='submit']", text: "Next"))
    |> assert_text("Start your 3-month free trial")
    |> click(button("Start Trial"))
    |> assert_url_contains("stripe-checkout")

    assert_receive {:checkout_linked, %{success_url: stripe_success_url}}

    session
    |> visit(stripe_success_url)
    |> assert_text("Your 3-month free trial has started!")
    |> click(button("Go to my dashboard"))
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
               package_templates: [
                 %{base_price: %Money{amount: 500}, shoot_count: 2, download_count: 10}
               ],
               profile: %{
                 website: "https://example.com",
                 no_website: false,
                 color: ^second_color,
                 job_types: ~w(event portrait)
               }
             }
           } = user
  end

  feature "user logs out during onboarding", %{session: session} do
    session
    |> assert_path(@onboarding_path)
    |> assert_disabled_submit()
    |> click(link("Logout"))
    |> assert_path("/")
    |> assert_flash(:info, text: "Logged out successfully")
  end

  feature "user goes back while onboarding", %{session: session, user: user} do
    session
    |> assert_path(@onboarding_path)
    |> assert_disabled_submit()
    |> fill_in_step(2)
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> assert_text("speciality")
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
