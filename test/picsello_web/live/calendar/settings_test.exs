defmodule PicselloWeb.Live.Calendar.SettingsTest do
  use PicselloWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  # alias PicselloWeb.Endpoint
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  alias Picsello.Accounts
  @token "A77LHd1ubDFRdxU64AwZKIyvN7sDfB"

  setup do
    ExVCR.Config.filter_request_headers("Authorization")
    ExVCR.Config.filter_request_options("basic_auth")

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

    @tag :skip
    test "Settings page with token error", %{conn: conn, user: user} do
      {:ok, _view, html} = load_page(conn, user)
      assert element_present?(html, "#error")
    end
  end

  describe "Read/write section" do
    test "Element Absent with No token", %{conn: conn, user: user} do
      {:ok, _view, html} = load_page(conn, user)
      refute element_present?(html, "#calendar_read_write")
    end

    test "Section present with Token", %{conn: conn, user: user} do
      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_selection_present" do
        {:ok, _view, html} = load_page(conn, user, :token)
        assert element_present?(html, "#calendar_read_write")
      end
    end

    test "Section checkboxes present", %{conn: conn, user: user} do
      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_selection_checkboxes_present" do
        {:ok, _view, html} = load_page(conn, user, :token)
        assert element_present?(html, "#calendar_read_write")
        elements = find_element(html, "input[type='radio'][name='calendar_read_write']")
        assert length(elements) == 16
      end
    end

    test "Section Radiobuttons have action", %{conn: conn, user: user} do
      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_selection_checkboxes_action" do
        {:ok, view, html} = load_page(conn, user, :token)

        assert find_element(html, "input[type='radio'][phx-click='calendar-read-write']")
               |> length ==
                 16

        assert find_element(html, "input[type='radio'][phx-value-calendar]") |> length ==
                 16
        {"input", attrs, _} = html |>find_element( "input[type='checkbox'][phx-value-calendar]") |> hd()
        val = Map.new(attrs)["value"]

        assert render_change(view, "calendar-read-write", %{"calendar" => val})

        
      end
    end

    @tag :skip
    test "Click checkbox changes calendar", %{conn: conn, user: user} do
      {:ok, _view, _html} = load_page(conn, user, :token)

    end
  end

  describe "Read only section" do
    test "Element absent with no token", %{conn: conn, user: user} do
      {:ok, _view, html} = load_page(conn, user)
      refute element_present?(html, "#syncing")
    end

    test "Section Present with Token", %{conn: conn, user: user} do
      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_selection_radio_buttons" do
        {:ok, _view, html} = load_page(conn, user, :token)
        assert element_present?(html, "#calendar_read")
      end
    end

    test "checkbox buttons present with token", %{conn: conn, user: user} do
      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_selection_checkbox_buttons" do
        {:ok, _view, html} = load_page(conn, user, :token)
        assert element_present?(html, "#calendar_read")
        elements = find_element(html, "input[type='checkbox'][name='calendar_read']")
        assert length(elements) == 16
      end
    end

    test "Section Checkboxes have action", %{conn: conn, user: user} do
      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_selection_checkbox_buttons_actions" do
        {:ok, view, html} = load_page(conn, user, :token)

        assert find_element(html, "input[type='checkbox'][phx-click='calendar-read']") |> length ==
                 16

        assert find_element(html, "input[type='checkbox'][phx-value-calendar]") |> length ==
                 16
        {"input", attrs, _} = html |>find_element( "input[type='checkbox'][phx-value-calendar]") |> hd()
        val = Map.new(attrs)["value"]

        assert render_change(view, "calendar-read", %{"calendar" => val})

      end
    end

    test "CLick checkbox changes calendar", %{conn: conn, user: user} do
      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_checkbox_changes_calendar" do

        {:ok, _view, _html} = load_page(conn, user, :token)
        
      end
    end
  end

  describe "Settings Page with connected calendars" do
    test "Google Calendar shows connected to", %{conn: conn, user: user} do
      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_calendar_connected" do

        {:ok, _view, html} = load_page(conn, user, :token)
        assert element_present?(html, "#syncing")
      end
    end

    test "Danger Zone/ Disconnect Calendar", %{conn: conn, user: user} do
      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_disconnect_calendar" do
        
        {:ok, view, html} = load_page(conn, user, :token)
        calendar_command = "disconnect_calendar"
        assert element_present?(html, "#danger")
        assert element_present?(html, "#disconnect_button")
        assert html |> find_element("#disconnect_button") |> Floki.text() == "Disconnect"
        
        assert html |> find_element("#disconnect_button") |> Floki.attribute("phx-click") == [
          calendar_command
        ]
        
        render_click(view, calendar_command)
        user = Accounts.get_user_by_email(user.email)
        assert is_nil(user.nylas_oauth_token)
        #refute element_present?(html, "#danger")
      end
    end

    test "Share Calendar", %{conn: conn, user: user} do
      ExVCR.Config.filter_request_headers("Authorization")

      use_cassette "#{__MODULE__}_share_calendar" do

        {:ok, _view, html} = load_page(conn, user, :token)
        
        assert element_present?(html, "#share")
      end
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
