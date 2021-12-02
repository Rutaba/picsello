defmodule Picsello.FeatureCase do
  @moduledoc false

  defmodule FeatureHelpers do
    @moduledoc "available in all FeatureCase tests"
    import Wallaby.{Browser, Query}
    import ExUnit.Assertions
    import Picsello.Factory

    def fill_in_date(session, field, opts \\ []) do
      date = Keyword.get(opts, :with)
      input = find(session, field)

      date =
        with "date" <- Wallaby.Element.attr(input, "type"),
             {:ok, date} <- DateTime.new(date, ~T[00:00:00]) do
          date
        else
          _ -> date
        end

      unix = DateTime.to_unix(%{date | second: 0})

      "" <> id = Wallaby.Element.attr(input, "id")

      execute_script(
        session,
        "document.getElementById(arguments[0]).valueAsNumber = arguments[1];",
        [id, unix * 1000],
        &send(self(), {:result, &1})
      )

      receive do
        {:result, _} -> nil
      end

      session
    end

    def post(session, path, body, headers \\ []) do
      HTTPoison.post(
        PicselloWeb.Endpoint.url() <> path,
        body,
        headers ++
          [
            {"user-agent", user_agent(session)}
          ]
      )

      session
    end

    def user_agent(session) do
      session
      |> execute_script("return navigator.userAgent;", [], &send(self(), {:user_agent, &1}))

      receive do
        {:user_agent, agent} -> agent
      end
    end

    def testid(id, opts \\ []), do: css("*[data-testid='#{id}']", opts)

    def wait_for_enabled_submit_button(session, opts \\ []) do
      session |> assert_has(css("button:not(:disabled)[type='submit']", opts))
    end

    def assert_disabled_submit(session, opts \\ []) do
      session |> assert_has(css("button:disabled[type='submit']", opts))
    end

    def within_modal(session, fun), do: find(session, css("#modal-wrapper"), fun)

    def assert_flash(session, key, opts \\ []) do
      try do
        session |> assert_has(css("*[role='alert'][title='#{key}']", opts))
      rescue
        e ->
          flash_messages =
            for el <- all(session, css("*[role='alert']")),
                do: {Wallaby.Element.attr(el, "title"), Wallaby.Element.text(el)},
                into: %{}

          message = "#{e.message}\nflash messages: #{inspect(flash_messages)}\n"

          reraise(%{e | message: message}, __STACKTRACE__)
      end
    end

    def sign_in(
          session,
          %{email: email},
          password \\ valid_user_password()
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

    def authenticated(%{session: session, user: user}) do
      sign_in(session, user)

      [session: session, user: user]
    end

    def authenticated(%{session: session}) do
      authenticated(%{session: session, user: insert(:user)})
    end

    def onboarded(%{user: user}) do
      [user: Picsello.Factory.onboard!(user)]
    end

    def onboarded(_), do: onboarded(%{user: insert(:user)})

    def definition(term, opts \\ []) do
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

    def assert_url_contains(session, url_fragment) do
      retry(fn ->
        if session |> current_url |> String.contains?(url_fragment),
          do: {:ok, nil},
          else: {:error, nil}
      end)

      url = session |> current_url()

      assert String.contains?(url, url_fragment), "expected #{url} to contain #{url_fragment}"

      session
    end

    def assert_disabled(session, %Wallaby.Element{} = el) do
      disabled = session |> all(css("*:disabled"))

      assert Enum.member?(disabled, el)

      session
    end

    def assert_disabled(session, %Wallaby.Query{} = query),
      do: assert_disabled(session, session |> find(query))

    @disableable ~w(input select textarea button)
                 |> Enum.map(&"#{&1}:not(:disabled)")
                 |> Enum.join(",")

    def assert_enabled(session, %Wallaby.Element{} = el) do
      enabled = all(session, css(@disableable))

      assert Enum.member?(enabled, el)

      session
    end

    def assert_enabled(session, %Wallaby.Query{} = query),
      do: assert_enabled(session, find(session, query))

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
      import Picsello.{Factory, FeatureCase.FeatureHelpers}
      alias PicselloWeb.Router.Helpers, as: Routes

      setup do
        Mox.stub_with(Picsello.MockPayments, Picsello.StripePayments)
        Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)
        :ok
      end
    end
  end
end
