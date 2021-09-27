defmodule PicselloWeb.AuthControllerTest do
  use PicselloWeb.ConnCase, async: false
  alias Picsello.{Repo, Accounts.User}

  setup do
    mock_auth =
      Picsello.MockAuthStrategy
      |> Mox.stub(:default_options, fn -> [ignores_csrf_attack: true] end)
      |> Mox.stub(:handle_cleanup!, & &1)
      |> Mox.stub(:handle_callback!, & &1)

    [auth: mock_auth]
  end

  test "puts error in flash when user can't be created from auth", %{conn: conn, auth: auth} do
    auth
    |> Mox.stub(:auth, fn _ ->
      %Ueberauth.Auth{
        info: %Ueberauth.Auth.Info{name: "", email: "brian@example.com"},
        provider: :google
      }
    end)

    assert conn
           |> get(Routes.auth_path(conn, :callback, :google))
           |> get_flash("error")
           |> String.contains?("contact support")
  end

  describe "when no user matches email" do
    test "creates a user and records the provider", %{conn: conn, auth: auth} do
      auth
      |> Mox.stub(:auth, fn _ ->
        %Ueberauth.Auth{
          info: %Ueberauth.Auth.Info{name: "brian", email: "brian@example.com"},
          provider: :google
        }
      end)

      conn
      |> put_req_cookie("time_zone", "America/Chicago")
      |> get(Routes.auth_path(conn, :callback, :google))

      assert %{name: "brian", time_zone: "America/Chicago", sign_up_auth_provider: :google} =
               User |> Repo.get_by(email: "brian@example.com")
    end
  end
end
