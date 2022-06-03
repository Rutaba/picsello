defmodule PicselloWeb.UserRegistrationControllerTest do
  use PicselloWeb.ConnCase, async: true

  setup do
    insert(:subscription_plan)

    insert(:subscription_plan,
      recurring_interval: "year",
      stripe_price_id: "price_987",
      price: 50_000,
      active: true
    )

    :ok
  end

  describe "GET /users/register" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, Routes.user_registration_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "Sign Up"
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in_user(insert(:user)) |> get(Routes.user_registration_path(conn, :new))
      assert redirected_to(conn) == "/home"
    end
  end
end
