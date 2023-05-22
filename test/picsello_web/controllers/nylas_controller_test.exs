defmodule PicselloWeb.NylasControllerTest do
  use PicselloWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Picsello.Accounts

  setup do
    %{user: insert(:user) |> onboard!, password: valid_user_password()}
  end

  describe "Nylas OAuth code" do
    test "puts session token and redirects to gallery", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_user(user)
        |> get("/nylas/callback", %{
          "code" => "HfHP3lDgBQIQRWRQLWBZLOiOwOQ5ls"
        })

      response = text_response(conn, 200)

      assert response == "OK"
    end

    test "Add Nylas code to user object", %{conn: conn, user: user} do
      assert is_nil(user.nylas_oauth_token)

      conn
      |> log_in_user(user)
      |> get("/nylas/callback", %{
        "code" => "HfHP3lDgBQIQRWRQLWBZLOiOwOQ5ls"
      })

      user = Accounts.get_user_by_email(user.email)
      assert user.nylas_oauth_token == "HfHP3lDgBQIQRWRQLWBZLOiOwOQ5ls"
    end

    test "Show button when there is no nylas oauth token", %{conn: conn, user: user} do
      Accounts.set_user_nylas_code(user, nil)

      conn =
        conn
        |> log_in_user(user)
        |> get("/calendar")

      assert html_response(conn, 200)

      {:ok, _view, html} = live(conn)

      assert html
             |> Floki.parse_document!()
             |> Floki.find("span#connect")
             |> Floki.text() == "Connect Calendar"
    end

    test "Hide button when there is is a nylas oauth token", %{conn: conn, user: user} do
      Accounts.set_user_nylas_code(user, "XXXXXX")

      conn =
        conn
        |> log_in_user(user)
        |> get("/calendar")

      assert html_response(conn, 200)

      {:ok, _view, html} = live(conn)

      assert html
             |> Floki.parse_document!()
             |> Floki.find("span#connect")
             |> Floki.text() == "Calendar Connected"
    end

    test "Sync calendar event from google to picsello via nylas", %{conn: _conn, user: _user} do
      throw(:not_yet_implemented)
    end

    test "Sync calendar event from picsello to google via nylas", %{conn: _conn, user: _user} do
      throw(:not_yet_implemented)
    end

    test "Show calendar event on picsello", %{conn: _conn, user: _user} do
      throw(:not_yet_implemented)
    end
  end
end
