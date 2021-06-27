defmodule Picsello.FeatureCase do
  @moduledoc false

  defmodule FeatureHelpers do
    alias Picsello.AccountsFixtures
    import Wallaby.{Browser, Query}
    import ExUnit.Assertions

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

    def definition(term, opts) do
      xpath("//dt[contains(./text(), '#{term}')]/following-sibling::dd[1]", opts)
    end

    def assert_value(session, query, value) do
      actual = session |> find(query) |> Wallaby.Element.value()
      assert value == actual
      session
    end

    def assert_path(session, path) do
      retry(fn ->
        if path == current_path(session), do: {:ok, nil}, else: {:error, nil}
      end)

      assert path == current_path(session)

      session
    end

    def navigate_to_forgot_password(session) do
      session
      |> visit("/")
      |> click(css("a", text: "Log In"))
      |> click(css("a", text: "Forgot Password"))
    end
  end

  use ExUnit.CaseTemplate

  using do
    quote do
      use Wallaby.Feature
      import Wallaby.Query
      import Picsello.FeatureCase.FeatureHelpers
    end
  end
end
