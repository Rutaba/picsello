defmodule Picsello.UserOnboardsTest do
  use Picsello.FeatureCase, async: false

  alias Picsello.{Accounts.User, Profiles, Repo}

  setup :authenticated

  setup %{session: session, user: user} do
    test_pid = self()

    Tesla.Mock.mock_global(fn
      %{method: :put} = request ->
        send(test_pid, {:sendgrid_request, request})

        body = %{"job_id" => "1234"}

        %Tesla.Env{status: 202, body: body}

      %{method: :post} = request ->
        send(test_pid, {:zapier_request, request})

        body = %{
          "attempt" => "1234",
          "id" => "1234",
          "request_id" => "1234",
          "status" => "success"
        }

        %Tesla.Env{status: 200, body: body}
    end)

    insert(:brand_link, user: user)

    insert(:cost_of_living_adjustment)
    insert(:cost_of_living_adjustment, state: "Non-US")

    insert(:package_tier)
    insert(:package_base_price, base_price: 300)
    subscription_plan = insert(:subscription_plan)
    [session: visit(session, "/"), subscription_plan: subscription_plan]
  end

  @onboarding_path Routes.onboarding_path(PicselloWeb.Endpoint, :index)
  @org_name_field text_field("onboarding-step-2_organization_name")
  @photographer_years_field text_field("onboarding-step-2_onboarding_photographer_years")

  def fill_in_step(session, 2) do
    session
    |> fill_in(@photographer_years_field, with: "5")
    |> click(option("OK"))
  end

  feature "user onboards", %{session: session, user: user, subscription_plan: subscription_plan} do
    user =
      user
      |> Repo.reload()
      |> Repo.preload(organization: :brand_links)

    home_path = Routes.home_path(PicselloWeb.Endpoint, :index)

    test_pid = self()

    Picsello.MockPayments
    |> Mox.stub(:create_session, fn params, opts ->
      send(
        test_pid,
        {:checkout_linked, opts |> Enum.into(params)}
      )

      {:ok, %Stripe.Session{url: "https://example.com/stripe-checkout"}}
    end)
    |> Mox.stub(:retrieve_session, fn "{CHECKOUT_SESSION_ID}", _opts ->
      {:ok, %Stripe.Session{subscription: "sub_123"}}
    end)
    |> Mox.stub(:create_customer, fn %{}, _opts ->
      {:ok, %Stripe.Customer{id: "cus_123"}}
    end)
    |> Mox.stub(:retrieve_customer, fn "cus_123", _ ->
      {:ok, %Stripe.Customer{invoice_settings: %{default_payment_method: "pm_12345"}}}
    end)
    |> Mox.stub(:create_subscription, fn %{}, _opts ->
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
    |> assert_value(@org_name_field, user.organization.name)
    |> fill_in(@org_name_field, with: "")
    |> assert_has(css("span.invalid-feedback", text: "Photography business name can't be blank"))
    |> fill_in(@org_name_field, with: "Photogenious")
    |> fill_in(@photographer_years_field, with: "5")
    |> click(option("OK"))
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> assert_disabled_submit()
    |> click(css("label", text: "Portrait"))
    |> click(css("label", text: "Event"))
    |> wait_for_enabled_submit_button()
    |> click(css("button[type='submit']", text: "Start Trial"))
    |> wait_for_enabled_submit_button()
    |> assert_path(home_path)

    user =
      user
      |> Repo.reload()
      |> Repo.preload(organization: [:package_templates, :organization_job_types])

    first_color = Picsello.Profiles.colors() |> hd

    assert %User{
             onboarding: %{
               schedule: :full_time,
               phone: nil,
               photographer_years: 5,
               switching_from_softwares: nil,
               completed_at: %DateTime{}
             },
             organization: %{
               name: "Photogenious",
               slug: "photogenious" <> _,
               package_templates: [
                 %{base_price: %Money{amount: 500}, shoot_count: 2, download_count: 10}
               ],
               profile: %{
                 color: ^first_color
               }
             }
           } = user

    assert ["event", "portrait"] =
             Profiles.enabled_job_types(user.organization.organization_job_types)

    assert_received {:sendgrid_request, %{body: sendgrid_request_body}}

    assert_received {:zapier_request, %{body: zapier_request_body}}

    user_email = user.email

    assert %{
             "email" => ^user_email
           } = Jason.decode!(zapier_request_body)

    assert %{
             "list_ids" => [
               "client-list-transactional-id",
               "client-list-trial-welcome-id"
             ],
             "clients" => [
               %{
                 "state_province_region" => "OK",
                 "custom_fields" => %{
                   "w3_T" => "Photogenious",
                   "w1_T" => "trial"
                 }
               }
             ]
           } = Jason.decode!(sendgrid_request_body)
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

    user = user |> Repo.reload() |> Repo.preload(organization: :organization_job_types)

    assert %User{
             onboarding: %{schedule: :full_time}
           } = user

    assert [] = Profiles.enabled_job_types(user.organization.organization_job_types)
  end

  feature "user selects Non-US state", %{session: session, user: user} do
    session
    |> assert_path(@onboarding_path)
    |> fill_in(@org_name_field, with: "Photogenious")
    |> fill_in(@photographer_years_field, with: "5")
    |> click(option("Non-US"))
    |> click(button("Next"))
    |> assert_text("speciality")

    user = user |> Repo.reload()

    assert %User{onboarding: %{state: "Non-US"}} = user
  end

  feature "user is redirected to onboarding", %{session: session} do
    session
    |> assert_path(@onboarding_path)
    |> visit(Routes.job_path(PicselloWeb.Endpoint, :jobs))
    |> assert_path(@onboarding_path)
    |> assert_text("Tell us more about yourself")
  end
end
