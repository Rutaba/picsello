defmodule Picsello.UserOnboardsTest do
  @moduledoc false
  use Picsello.FeatureCase, async: false

  import Ecto.Changeset

  alias Picsello.{Accounts.User, Profiles, Repo}

  setup %{session: session} do
    user =
      insert(:user)
      |> cast(%{onboarding_flow_source: ["mastermind"]}, [:onboarding_flow_source])
      |> Repo.update!()

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
    insert(:package_base_price, base_price: %{amount: 300, currency: :USD})
    [subscription_plan | _] = insert_subscription_plans!()

    insert(:subscription_promotion_codes,
      code: "BLACKFRIDAY2024",
      stripe_promotion_code_id: "asdf231",
      percent_off: 45.86
    )

    [
      session: sign_in(session, user),
      user: user,
      subscription_plan: subscription_plan
    ]
  end

  @onboarding_path Routes.onboarding_mastermind_path(PicselloWeb.Endpoint, :index)
  @org_name_field text_field("onboarding-step-3_organization_name")
  @photographer_years_field text_field("onboarding-step-3_onboarding_photographer_years")
  @interested_in_field select("onboarding-step-3_onboarding_interested_in")

  def fill_in_step(session, 2) do
    session
    |> fill_in(@photographer_years_field, with: "5")
    |> find(@interested_in_field, &click(&1, option("Booking Events")))
    |> click(option("OK"))
  end

  feature "user onboards", %{session: session, user: user, subscription_plan: subscription_plan} do
    user =
      user
      |> Repo.reload()
      |> Repo.preload(organization: :brand_links)

    home_path = Routes.home_path(PicselloWeb.Endpoint, :index)

    Picsello.MockPayments
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

    session
    |> assert_path(@onboarding_path)
    |> assert_text("is here to help")
    |> sleep(4000)
    |> focus_frame(css("#address-element iframe:first-child"))
    |> fill_in(text_field("addressLine1"), with: "123 Main St")
    |> focus_default_frame()
    |> focus_frame(css("#address-element iframe:last-child"))
    |> click(css(".p-DropdownItem:first-child"))
    |> focus_default_frame()
    |> focus_frame(css("#address-element iframe:first-child"))
    |> fill_in(text_field("locality"), with: "Picsello")
    |> find(select("administrativeArea"), &click(&1, option("New York")))
    |> fill_in(text_field("postalCode"), with: "12345")
    |> focus_default_frame()
    |> focus_frame(css("#payment-element iframe:first-child"))
    |> fill_in(text_field("number"), with: "4242424242424242")
    |> fill_in(text_field("expiry"), with: "1231")
    |> fill_in(text_field("cvc"), with: "123")
    |> focus_default_frame()
    |> click(css("#payment-element-submit"))
    |> assert_text("Processing payment")
    |> visit(
      Routes.onboarding_mastermind_path(PicselloWeb.Endpoint, :index,
        state: "OK",
        country: "US",
        promotion_code: "BLACKFRIDAY2024",
        redirect_status: "succeeded",
        payment_intent: "pi_123"
      )
    )
    |> assert_value(@org_name_field, user.organization.name)
    |> fill_in(@org_name_field, with: "")
    |> assert_has(css("span.invalid-feedback", text: "Photography business name can't be blank"))
    |> fill_in(@org_name_field, with: "Photogenious")
    |> fill_in(@photographer_years_field, with: "5")
    |> find(@interested_in_field, &click(&1, option("Booking Events")))
    |> wait_for_enabled_submit_button()
    |> click(button("Next"))
    |> sleep(250)
    |> click(css("label", text: "Portrait"))
    |> click(css("label", text: "Event"))
    |> wait_for_enabled_submit_button()
    |> click(css("button[type='submit']", text: "Finish"))
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

    assert ["event", "mini", "other", "portrait"] =
             Profiles.enabled_job_types(user.organization.organization_job_types) |> Enum.sort()

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
    |> click(link("Logout"))
    |> assert_path("/")
    |> assert_flash(:info, text: "Logged out successfully")
  end
end
