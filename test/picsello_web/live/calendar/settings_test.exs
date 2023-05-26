defmodule PicselloWeb.Live.Calendar.SettingsTest do
  use PicselloWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  # alias PicselloWeb.Endpoint
  alias Picsello.Accounts
  @token "HfHP3lDgBQIQRWRQLWBZLOiOwOQ5ls"

  setup do
    %{user: insert(:user) |> onboard!, password: valid_user_password()}
  end

  test "Load Page", %{conn: conn, user: user} do
    {:ok, _, _} = load_page(conn, user)
  end

  describe "Settings Page with out connected calendars" do
    test "Danger Zone/ Disconnect Calendar", %{conn: conn, user: user} do
      {:ok, _view, html} = load_page(conn, user)
      refute element_present?(html, "#danger")
    end

    test "Google Calendar shows connected to", %{conn: conn, user: user} do
      {:ok, _view, html} = load_page(conn, user)
      refute element_present?(html, "#calendar_read")
    end

    test "Read Write section", %{conn: conn, user: user} do
      {:ok, _view, html} = load_page(conn, user)
      refute element_present?(html, "#calendar_read_write")
    end

    test "Google Calendar read", %{conn: conn, user: user} do
      {:ok, _view, html} = load_page(conn, user)
      refute element_present?(html, "#syncing")
    end
  end

  describe "Settings Page with connected calendars" do
    test "Google Calendar shows connected to", %{conn: conn, user: user} do
      {:ok, _view, html} = load_page(conn, user, :token)
      assert element_present?(html, "#syncing")
    end

    test "Read Write section", %{conn: conn, user: user} do
      {:ok, _view, html} = load_page(conn, user, :token)
      assert element_present?(html, "#calendar_read_write")
    end

    test "Google Calendar read", %{conn: conn, user: user} do
      {:ok, _view, html} = load_page(conn, user, :token)
      assert element_present?(html, "#calendar_read")
    end

    test "Danger Zone/ Disconnect Calendar", %{conn: conn, user: user} do
      {:ok, view, html} = load_page(conn, user, :token)
      calendar_command = "disconnect_calendar"
      assert element_present?(html, "#danger")
      assert element_present?(html, "#disconnect_button")
      assert html |> find_element("#disconnect_button") |> Floki.text() == "Disconnect"

      assert html |> find_element("#disconnect_button") |> Floki.attribute("phx-click") == [
               calendar_command
             ]

      html = render_click(view, calendar_command)
      user = Accounts.get_user_by_email(user.email)
      assert is_nil(user.nylas_oauth_token)
      refute element_present?(html, "#danger")
    end

    test "Share Calendar", %{conn: conn, user: user} do
      {:ok, _view, html} = load_page(conn, user, :token)

      assert element_present?(html, "#share")
    end
  end

  test "Share your Picsello Calendar", %{conn: conn, user: user} do
    {:ok, _view, html} = load_page(conn, user)

    url =
      html
      |> Floki.parse_document!()
      |> Floki.find("#copy-calendar-link")
      |> Floki.attribute("data-clipboard-text")
      |> hd()

    assert url ==
             html
             |> Floki.parse_document!()
             |> Floki.find("#subscribe-calendar-url")
             |> Floki.text()
  end

  def element_present?(html, selector) do
    html
    |> Floki.parse_document!()
    |> Floki.find(selector) !=
      []
  end

  def find_element(html, selector) do
    html
    |> Floki.parse_document!()
    |> Floki.find(selector)
  end

  def load_page(conn, user) do
    conn =
      conn
      |> log_in_user(user)
      |> get("/calendar/settings")

    assert html_response(conn, 200)

    live(conn)
  end

  def load_page(conn, user, :token) do
    Accounts.set_user_nylas_code(user, @token)

    conn =
      conn
      |> log_in_user(user)
      |> get("/calendar/settings")

    assert html_response(conn, 200)

    live(conn)
  end
end
