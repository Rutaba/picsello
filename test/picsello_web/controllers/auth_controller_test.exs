defmodule PicselloWeb.AuthControllerTest do
  use PicselloWeb.ConnCase, async: false
  alias Picsello.{Repo, Accounts.User}

  setup do
    test_pid = self()

    Tesla.Mock.mock_global(fn
      %{method: :put} = request ->
        send(test_pid, {:sendgrid_request, request})

        body = %{"job_id" => "1234"}

        %Tesla.Env{status: 202, body: body}

      %{method: :post} = request ->
        send(test_pid, {:zapier_request, request})

        body = %{
          "attempt" => "1234",
          "id" => "1234",
          "request_id" => "1234",
          "status" => "success"
        }

        %Tesla.Env{status: 200, body: body}
    end)

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

      assert_received {:sendgrid_request, %{body: sendgrid_request_body}}

      assert_received {:zapier_request, %{body: zapier_request_body}}

      assert %{
               "email" => "brian@example.com"
             } = Jason.decode!(zapier_request_body)

      assert %{
               "list_ids" => [
                 "client-list-transactional-id",
                 "client-list-trial-welcome-id"
               ],
               "clients" => [
                 %{
                   "custom_fields" => %{
                     "w1_T" => "pre_trial"
                   },
                   "email" => "brian@example.com",
                   "first_name" => "brian",
                   "last_name" => nil
                 }
               ]
             } = Jason.decode!(sendgrid_request_body)
    end
  end
end
