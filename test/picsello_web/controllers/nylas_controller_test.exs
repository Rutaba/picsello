defmodule PicselloWeb.NylasControllerTest do
  use PicselloWeb.ConnCase, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  import Phoenix.LiveViewTest
  alias Picsello.Accounts
  @modal_command "toggle_connect_modal"
  setup do
    %{user: insert(:user) |> onboard!, password: valid_user_password()}
  end

  describe "Nylas OAuth code" do
    test "Redirect without a logged in user", %{conn: conn} do
      assert %Plug.Conn{status: 302, resp_headers: headers} =
               conn
               |> get("/nylas/callback", %{
                 "code" => "HfHP3lDgBQIQRWRQLWBZLOiOwOQ5ls"
               })

      assert Enum.member?(headers, {"location", "/users/log_in"})
    end

    @tag :skip
    test "puts session token and redirects to gallery", %{conn: conn, user: user} do
      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_put_session_token" do
        assert %Plug.Conn{status: 302, resp_headers: headers} =
                 conn
                 |> log_in_user(user)
                 |> get("/nylas/callback", %{
                   "code" => "HfHP3lDgBQIQRWRQLWBZLOiOwOQ5ls"
                 })

        assert Enum.member?(headers, {"location", "/calendar"})
      end
    end

    @tag :skip
    test "Add Nylas code to user object", %{conn: conn, user: user} do
      assert is_nil(user.nylas_oauth_token)
      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_add_to_user_object" do
        conn
        |> log_in_user(user)
        |> get("/nylas/callback", %{
          "code" => "HfHP3lDgBQIQRWRQLWBZLOiOwOQ5ls"
        })

        user = Accounts.get_user_by_email(user.email)
        assert user.nylas_oauth_token == "HfHP3lDgBQIQRWRQLWBZLOiOwOQ5ls"
      end
    end

    test "Show button when there is no nylas oauth token", %{conn: conn, user: user} do
      Accounts.set_user_nylas_code(user, nil)

      {:ok, _view, html} = load_page(conn, user)

      assert html
             |> Floki.parse_document!()
             |> Floki.find("span#connect")
             |> Floki.text() == "Connect Calendar"
    end

    test "Hide button when there is is a nylas oauth token", %{conn: conn, user: user} do
      Accounts.set_user_nylas_code(user, "XXXXXX")

      {:ok, _view, html} = load_page(conn, user)

      assert html
             |> Floki.parse_document!()
             |> Floki.find("span#connect")
             |> Floki.text() == "Calendar Connected"
    end

    test "Open & Close  Modal Connect your calendar dialog", %{conn: conn, user: user} do
      {:ok, view, _html} = load_page(conn, user)
      assert render_click(view, @modal_command)

      assert view
             |> render()
             |> Floki.parse_document!()
             |> Floki.find("#connect_calendar_modal")
             |> Floki.find("h1")
             |> Floki.text() =~ "Connect your calendar"

      assert render_click(view, @modal_command)

      assert view
             |> render()
             |> Floki.parse_document!()
             |> Floki.find("div##{@modal_command}") == []
    end

    test "Open Modal has correct action", %{conn: conn, user: user} do
      {:ok, _view, html} = load_page(conn, user)

      assert html
             |> Floki.parse_document!()
             |> Floki.find("div#button-connect")
             |> Floki.attribute("phx-click")
             |> Enum.member?(@modal_command)
    end

    test "Close has correct action", %{conn: conn, user: user} do
      {:ok, view, _html} = load_page(conn, user)

      assert view
             |> render_click(@modal_command)
             |> Floki.parse_document!()
             |> Floki.find("#button-close")
             |> Floki.attribute("phx-click")
             |> Enum.member?(@modal_command)
    end

    test "Open & Check link", %{conn: conn, user: user} do
      {:ok, view, _html} = load_page(conn, user)

      assert render_click(view, @modal_command)
      {:ok, link} = NylasCalendar.generate_login_link()

      assert view
             |> render()
             |> Floki.parse_document!()
             |> Floki.find("#button-connect")
             |> Floki.attribute("href") == [link]
    end

    def get_state(%Phoenix.LiveViewTest.View{pid: pid}) do
      :sys.get_state(pid)
    end

    def load_page(conn, user) do
      conn =
        conn
        |> log_in_user(user)
        |> get("/calendar")

      assert html_response(conn, 200)

      live(conn)
    end

    @tag :skip
    test "Sync calendar event from google to picsello via nylas", %{conn: _conn, user: _user} do
      throw(:not_yet_implemented)
    end

    @tag :skip
    test "Sync calendar event from picsello to google via nylas", %{conn: _conn, user: _user} do
      throw(:not_yet_implemented)
    end

    @tag :skip
    test "Show calendar event on picsello", %{conn: _conn, user: _user} do
      throw(:not_yet_implemented)
    end
  end
end
