defmodule PicselloWeb.NylasControllerTest do
  use PicselloWeb.ConnCase, async: true

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

      assert response =~ "OK"
    end

    test "Add Nylas code to user object", %{conn: _conn, user: _user} do
      throw(:NYI)
    end
  end
end
