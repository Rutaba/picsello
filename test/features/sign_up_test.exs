defmodule Picsello.SignUpTest do
  use Picsello.FeatureCase, async: false

  alias Picsello.{Repo, Accounts.User}

  setup do
    test_pid = self()

    insert_subscription_plans!()

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

    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)
    :ok
  end

  feature "user views sign up button", %{session: session} do
    session
    |> visit("/")
    |> assert_has(css("a", text: "Sign Up"))
  end

  feature "user signs up", %{session: session} do
    session
    |> visit("/")
    |> click(css("a", text: "Sign Up"))
    |> fill_in(text_field("Name"), with: "Mary Jane")
    |> fill_in(text_field("Email"), with: "user@example.com")
    |> fill_in(text_field("Password"), with: "ThisIsAStrongP@ssw0rd")
    |> set_cookie("time_zone", "FakeTimeZone")
    |> wait_for_enabled_submit_button()
    |> click(button("Sign up"))
    |> assert_path("/onboarding")

    user = User |> Repo.one() |> Repo.preload(:organization)
    insert(:brand_link, user: user)
    user |> Repo.reload() |> Repo.preload(organization: :brand_links)

    assert %{
             name: "Mary Jane",
             email: "user@example.com",
             time_zone: "FakeTimeZone",
             organization: %{name: "Mary Jane Photography", slug: "mary-jane-photography"}
           } = user

    assert_received {:sendgrid_request, %{body: sendgrid_request_body}}

    assert_received {:zapier_request, %{body: zapier_request_body}}

    assert %{
             "email" => "user@example.com"
           } = Jason.decode!(zapier_request_body)

    assert %{
             "list_ids" => [
               "contact-list-transactional-id",
               "contact-list-trial-welcome-id"
             ],
             "contacts" => [
               %{
                 "custom_fields" => %{
                   "w3_T" => "Mary Jane Photography",
                   "w1_T" => "pre_trial"
                 },
                 "email" => "user@example.com",
                 "first_name" => "Mary",
                 "last_name" => "Jane"
               }
             ]
           } = Jason.decode!(sendgrid_request_body)
  end

  feature "user sees validation error when signing up", %{session: session} do
    session
    |> visit("/")
    |> click(css("a", text: "Sign Up"))
    |> fill_in(text_field("Name"), with: "Mary Jane")
    |> fill_in(text_field("Email"), with: "user@example.com")
    |> fill_in(text_field("Password"), with: "123")
    |> assert_has(css("label", text: "Password should be at least 12 characters"))
    |> assert_has(css("button:disabled[type='submit']", text: "Sign up"))
    |> assert_path("/users/register")
  end

  feature "user toggles password visibility", %{session: session} do
    session
    |> visit("/")
    |> click(css("a", text: "Sign Up"))
    |> fill_in(text_field("Password"), with: "123")
    |> assert_has(css("#user_password[type='password']"))
    |> click(css("a", text: "show"))
    |> assert_has(css("#user_password[type='text']"))
    |> click(css("a", text: "hide"))
    |> assert_has(css("#user_password[type='password']"))
  end

  feature "user signs up with google", %{session: session} do
    Picsello.MockAuthStrategy
    |> Mox.stub(:default_options, fn -> [ignores_csrf_attack: true] end)
    |> Mox.stub(:handle_cleanup!, & &1)
    |> Mox.stub(:handle_callback!, & &1)
    |> Mox.stub(
      :handle_request!,
      &Ueberauth.Strategy.Helpers.redirect!(&1, Routes.auth_url(&1, :callback, :google))
    )
    |> Mox.stub(:auth, fn _ ->
      %Ueberauth.Auth{
        info: %Ueberauth.Auth.Info{name: "brian", email: "brian@example.com"},
        provider: :google
      }
    end)

    session
    |> visit("/")
    |> click(link("Sign Up"))
    |> click(link("Continue with Google"))
    |> assert_path("/onboarding")

    assert_received {:sendgrid_request, %{body: sendgrid_request_body}}

    assert_received {:zapier_request, %{body: zapier_request_body}}

    assert %{
             "email" => "brian@example.com"
           } = Jason.decode!(zapier_request_body)

    assert %{
             "list_ids" => [
               "contact-list-transactional-id",
               "contact-list-trial-welcome-id"
             ],
             "contacts" => [
               %{
                 "custom_fields" => %{
                   "w1_T" => "pre_trial"
                 },
                 "email" => "brian@example.com",
                 "first_name" => "brian",
                 "last_name" => nil
               }
             ]
           } = Jason.decode!(sendgrid_request_body)
  end

  feature "user has promotional code", %{session: session} do
    random_code = generate_random_code()
    insert_subscription_metadata_factory!(%{active: true, code: random_code})

    session
    |> visit("/users/register?code=#{random_code}")
    |> assert_has(
      css("h2",
        text: "90-day free"
      )
    )
  end

  feature "user has inactive/non-existent promotional code", %{session: session} do
    random_code = generate_random_code()
    insert_subscription_metadata_factory!(%{code: random_code})

    session
    |> visit("/users/register?code=#{random_code}")
    |> assert_has(
      css("h2",
        text: "30-day free"
      )
    )
  end
end
