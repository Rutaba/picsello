defmodule Picsello.FeatureCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      use ExUnit.Case, async: false
      use Wallaby.Feature
      import Wallaby.Query
      alias Picsello.AccountsFixtures

      def wait_for_enabled_submit_button(session) do
        session |> assert_has(css("button:not(:disabled)[type='submit']"))
      end

      def sign_in(
            session,
            %{email: email},
            password \\ AccountsFixtures.valid_user_password()
          ) do
        session
        |> maybe_visit_log_in()
        |> fill_in(text_field("Email"), with: email)
        |> fill_in(text_field("Password"), with: password)
        |> wait_for_enabled_submit_button()
        |> click(button("Log In"))
      end

      def maybe_visit_log_in(session) do
        if current_path(session) == "/users/log_in" do
          session
        else
          session |> visit("/users/log_in")
        end
      end

      def authenticated(%{session: session}) do
        user = AccountsFixtures.user_fixture()
        sign_in(session, user)

        [session: session, user: user]
      end
    end
  end
end
