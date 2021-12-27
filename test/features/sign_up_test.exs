defmodule Picsello.SignUpTest do
  use Picsello.FeatureCase, async: true

  alias Picsello.{Repo, Accounts.User}

  setup do
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

    assert %{
             name: "Mary Jane",
             email: "user@example.com",
             time_zone: "FakeTimeZone",
             organization: %{name: "Mary Jane Photography", slug: "mary-jane-photography"}
           } = user
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
  end
end
