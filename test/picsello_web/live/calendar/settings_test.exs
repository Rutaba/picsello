defmodule PicselloWeb.Live.Calendar.SettingsTest do
  use PicselloWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Picsello.Accounts
  @modal_command "toggle_connect_modal"
  setup do
    %{user: insert(:user) |> onboard!, password: valid_user_password()}
  end

  describe "Settings Page" do
    test "Load Page", %{conn: conn, user: user} do
      {:ok, _, _} = load_page(conn, user)
    end

    test "Google Calendar shows connected to", %{conn: _conn, user: _user} do
      throw(:not_yet_implemented)
    end

    test "Read Write section", %{conn: _conn, user: _user} do
      throw(:not_yet_implemented)
    end

    test "Google Calendar read", %{conn: _conn, user: _user} do
      throw(:not_yet_implemented)
    end

    test "Share your Picsello Calendar", %{conn: _conn, user: _user} do
      throw(:not_yet_implemented)
    end

    test "Danger Zone/ Disconnect Calendar", %{conn: _conn, user: _user} do
      throw(:not_yet_implemented)
    end
  end

  def load_page(conn, user) do
    conn =
      conn
      |> log_in_user(user)
      |> get("/calendar/settings")

    assert html_response(conn, 200)

    live(conn)
  end
end
