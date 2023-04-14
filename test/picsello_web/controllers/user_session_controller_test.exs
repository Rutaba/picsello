defmodule PicselloWeb.UserSessionControllerTest do
  use PicselloWeb.ConnCase, async: true

  setup do
    %{user: insert(:user) |> onboard!, password: valid_user_password()}
  end

  describe "GET /users/log_in" do
    test "renders log in page", %{conn: conn} do
      conn = get(conn, Routes.user_session_path(conn, :new))

      response =
        conn |> html_response(200) |> Floki.parse_document!() |> Floki.find("h1") |> Floki.text()

      assert response == "Log in"
    end

    test "redirects if already logged in", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> get(Routes.user_session_path(conn, :new))
      assert redirected_to(conn) == "/home"
    end
  end

  describe "POST /users/log_in" do
    test "logs the user in", %{conn: conn, user: user, password: password} do
      conn =
        post(conn, Routes.user_session_path(conn, :create), %{
          "user" => %{"email" => user.email, "password" => password}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == "/home"
    end

    test "logs the user in with remember me", %{conn: conn, user: user, password: password} do
      conn =
        post(conn, Routes.user_session_path(conn, :create), %{
          "user" => %{
            "email" => user.email,
            "password" => password,
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_picsello_web_user_remember_me"]
      assert redirected_to(conn) =~ "/home"
    end

    test "logs the user in with return to", %{conn: conn, user: user, password: password} do
      user |> onboard!

      conn =
        conn
        |> init_test_session(user_return_to: "/foo/bar")
        |> post(Routes.user_session_path(conn, :create), %{
          "user" => %{
            "email" => user.email,
            "password" => password
          }
        })

      assert redirected_to(conn) == "/foo/bar"
    end
  end

  describe "DELETE /users/log_out" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(Routes.user_session_path(conn, :delete))
      assert redirected_to(conn) == "/"
      refute get_session(conn, :user_token)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, Routes.user_session_path(conn, :delete))
      assert redirected_to(conn) == "/"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
