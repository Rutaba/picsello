defmodule PicselloWeb.NylasControllerTest do
  use PicselloWeb.ConnCase, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  import Phoenix.LiveViewTest
  alias Picsello.Accounts
  alias :meck, as: Meck
  @modal_command "toggle_connect_modal"
  @token "HfH******************************"
  setup do
    %{user: insert(:user) |> onboard!, password: valid_user_password()}
  end

  describe "Nylas OAuth code" do


    test "Redirect without a logged in user", %{conn: conn} do
      assert %Plug.Conn{status: 302, resp_headers: headers} =
               conn
               |> get("/nylas/callback", %{
                 "code" => @token
               })

      assert Enum.member?(headers, {"location", "/users/log_in"})
    end

    test "puts session token and redirects to gallery", %{conn: conn, user: user} do
      Meck.new(NylasCalendar)

      Meck.expect(NylasCalendar, :fetch_token, fn code ->
        assert code == @token
        {:ok, @token}
      end)

      assert %Plug.Conn{status: 302, resp_headers: headers} =
               conn
               |> log_in_user(user)
               |> get("/nylas/callback", %{
                 "code" => @token
               })

      assert Enum.member?(headers, {"location", "/calendar"})
      assert Meck.validate(NylasCalendar)
      Meck.unload(NylasCalendar)
      user = Accounts.get_user_by_email(user.email)
      assert user.nylas_oauth_token == @token
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
             |> Floki.text()
             |> String.trim() == "Calendar Sync Connected"
    end


    test "Open Modal has correct action", %{conn: conn, user: user} do
      {:ok, _view, html} = load_page(conn, user)

      assert html
             |> Floki.parse_document!()
             |> Floki.find("button#button-connect")
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

  end
end
