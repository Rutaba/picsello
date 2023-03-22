defmodule Picsello.FeatureCase do
  @moduledoc false

  defmodule FeatureHelpers do
    @moduledoc "available in all FeatureCase tests"
    import Wallaby.{Browser, Query}
    import ExUnit.Assertions
    import Picsello.Factory
    import Money.Sigils

    alias Picsello.Galleries.Photo

    def scroll_to_bottom(session),
      do: execute_script(session, "window.scrollTo(0, document.body.clientHeight)")

    def scroll_to_top(session),
      do: execute_script(session, "window.scrollTo(0, 0)")

    def scroll_into_view(session, query) do
      case Wallaby.Query.compile(query) do
        {:css, css_selector} ->
          session
          |> execute_script("document.querySelector(`#{css_selector}`).scrollIntoView()")

        {type, _selector} ->
          raise "#{type} not supported. Use a css selector"
      end
    end

    def run_jobs(opts \\ []) do
      ExUnit.CaptureLog.capture_log([level: :warn], fn ->
        opts |> Keyword.put_new(:queue, :default) |> Oban.drain_queue()
      end)

      Oban.Job |> Picsello.Repo.all()
    end

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

    def force_simulate_click(session, query) do
      case Wallaby.Query.compile(query) do
        {:css, selector} ->
          execute_script(
            session,
            "document.querySelector(arguments[0]).click()",
            [selector]
          )
      end
    end

    def replace_inner_content(session, query, content) do
      case Wallaby.Query.compile(query) do
        {:css, css_selector} ->
          session
          |> execute_script("""
          document.querySelector(`#{css_selector}`).innerHTML = "#{content}";
          """)
      end
    end

    def sleep(session, milliseconds) do
      :timer.sleep(milliseconds)
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

    def testid(id, opts \\ []) do
      {operator, opts} = Keyword.pop(opts, :op, "=")
      css("*[data-testid#{operator}'#{id}']", opts)
    end

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

    @sign_in_path "/users/log_in"

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
      |> click(button("Login"))
      |> then(&wait_for_path_to_change_from(&1, @sign_in_path))
    end

    def wait_for_path_to_change_from(session, path) do
      retry(fn ->
        if current_path(session) == path do
          {:error, "not redirected after sign in."}
        else
          {:ok, nil}
        end
      end)

      session
    end

    def maybe_visit_log_in(session) do
      if current_path(session) == @sign_in_path do
        session
      else
        session |> visit(@sign_in_path)
      end
    end

    def authenticated(%{session: session, user: user}) do
      [session: sign_in(session, user), user: user]
    end

    def authenticated(%{session: session}) do
      authenticated(%{session: session, user: insert(:user)})
    end

    def onboarded_show_intro(%{user: user}) do
      [user: Picsello.Factory.onboard_show_intro!(user)]
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

    def assert_selected_option(session, query, option_text) do
      actual =
        session |> find(query) |> find(css("option", selected: true)) |> Wallaby.Element.text()

      assert option_text == actual
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
      retry(
        fn ->
          if session |> current_url |> String.contains?(url_fragment),
            do: {:ok, nil},
            else: {:error, nil}
        end,
        :erlang.monotonic_time(:milli_seconds) + 500
      )

      url = current_url(session)

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

    def assert_inner_text(session, %Wallaby.Query{} = query, text) do
      session
      |> find(query, fn el ->
        inner_html = Wallaby.Element.attr(el, "innerHTML")
        assert inner_html |> Floki.text(deep: true) |> String.replace(~r/\s+/, " ") =~ text
      end)
    end

    def navigate_to_forgot_password(session) do
      session
      |> visit("/")
      |> click(css("a", text: "Log In"))
      |> click(css("a", text: "Forgot your password?"))
    end

    def authenticated_gallery_client(%{session: session, gallery: gallery}) do
      gallery_login(session, gallery)

      [session: session, gallery: gallery]
    end

    def authenticated_gallery_client(%{session: session}) do
      job = insert(:lead, type: "wedding", user: insert(:user)) |> promote_to_job()
      authenticated_gallery_client(%{session: session, gallery: insert(:gallery, job: job)})
    end

    def authenticated_proofing_album_client(%{session: session, proofing_album: proofing_album}) do
      proofing_album_login(session, proofing_album, proofing_album.password)

      [session: session, proofing_album: proofing_album]
    end

    def authenticated_proofing_album_client(%{session: session}) do
      organization = insert(:organization, stripe_account_id: "photographer-stripe-account-id")
      insert(:user, organization: organization)
      package = insert(:package, organization: organization, download_each_price: ~M[2500]USD)

      gallery =
        insert(:gallery,
          job:
            insert(:lead,
              client: insert(:client, organization: organization),
              package: package
            )
        )

      authenticated_proofing_album_client(%{
        session: session,
        proofing_album: insert(:proofing_album, %{gallery_id: gallery.id})
      })
    end

    def authenticated_gallery(%{session: session, user: user}) do
      organization = insert(:organization, user: user)
      client = insert(:client, organization: organization)
      package = insert(:package, organization: organization, download_each_price: ~M[2500]USD)
      job = insert(:lead, type: "wedding", client: client, package: package) |> promote_to_job()

      [session: session, gallery: insert(:gallery, %{job: job, total_count: 20})]
    end

    def authenticated_gallery(%{session: session}) do
      job = insert(:lead, type: "wedding", user: insert(:user)) |> promote_to_job()
      [session: session, gallery: insert(:gallery, job: job)]
    end

    def wait_for_focus(session, query) do
      {:css, selector} = Wallaby.Query.compile(query)

      retry(fn ->
        test_pid = self()

        session
        |> execute_script(
          "return document.activeElement === document.querySelector(arguments[0])",
          [selector],
          &send(test_pid, {:focused?, &1})
        )

        receive do
          {:focused?, true} -> {:ok, nil}
          {:focused?, false} -> {:error, "element not focused"}
        end
      end)

      session
    end

    @quill_text_area_query css("div.ql-editor")

    def focus_quill(session) do
      session
      |> find(css("div[phx-hook=Quill]"), fn quill ->
        quill
        |> click(@quill_text_area_query)
        |> wait_for_focus(@quill_text_area_query)
      end)
    end

    def fill_in_quill(session, text) do
      session
      |> focus_quill()
      |> find(css("div[phx-hook=Quill]"), fn quill ->
        retry(fn ->
          quill
          |> find(@quill_text_area_query, &send_keys(&1, text))
          |> find(css("input[type=hidden]", count: :any, visible: false))
          |> Enum.any?(&(&1 |> Wallaby.Element.attr("value") |> String.contains?(text)))
          |> if(do: {:ok, nil}, else: {:error, "quill didnt set the hidden"})
        end)
      end)
    end

    def insert_photo(%{gallery: %{id: gallery_id}, total_photos: total_photos} = data) do
      album = Map.get(data, :album, %{id: nil})
      photo_url = "/images/print.png"

      Enum.map(1..total_photos, fn index ->
        %Photo{
          album_id: album.id,
          gallery_id: gallery_id,
          preview_url: photo_url,
          original_url: photo_url,
          name: photo_url,
          aspect_ratio: 2,
          position: index + 100,
          width: 487,
          height: 358
        }
        |> insert()
        |> Map.get(:id)
      end)
    end

    defp proofing_album_login(session, proofing_album, password) do
      path = "/album/#{proofing_album.client_link_hash}"

      session
      |> visit(path)
      |> fill_in(css("#login_email"), with: "testing@picsello.com")
      |> fill_in(css("#login_password"), with: password)
      |> click(button("Submit"))
      |> then(&wait_for_path_to_change_from(&1, path <> "/login"))
    end

    defp gallery_login(session, gallery, password \\ valid_gallery_password()) do
      path = "/gallery/#{gallery.client_link_hash}"

      session
      |> visit(path)
      |> fill_in(css("#login_email"), with: "testing@picsello.com")
      |> fill_in(css("#login_password"), with: password)
      |> click(button("Submit"))
      |> then(&wait_for_path_to_change_from(&1, path <> "/login"))
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
        Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)
        :ok
      end
    end
  end
end
