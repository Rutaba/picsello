defmodule PicselloWeb.LiveAuthTest do
  use PicselloWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup do
    [user: insert(:user)]
  end

  @home_path Routes.home_path(PicselloWeb.Endpoint, :index)
  @onboarding_path Routes.onboarding_path(PicselloWeb.Endpoint, :index)

  describe "mount" do
    test "redirects to home if user is authenticated, onboarded and on onboarding path", %{
      user: user,
      conn: conn
    } do
      assert {:error, {:live_redirect, %{to: @home_path}}} =
               conn |> log_in_user(user |> onboard!()) |> live(@onboarding_path)
    end

    test "does not redirect if user is authenticated and onboarded and not on onboarding_path", %{
      conn: conn,
      user: user
    } do
      Mox.stub(Picsello.MockPayments, :status, fn _ -> :no_account end)

      assert {:ok, _, _} = conn |> log_in_user(user |> onboard!()) |> live(@home_path)
    end

    test "does not redirect if user is authenticated, on onboarding path and not onboarded", %{
      conn: conn,
      user: user
    } do
      assert {:ok, _, _} = conn |> log_in_user(user) |> live(@onboarding_path)
    end

    test "redirects to onboarding if user is authenticated, not onboarded and not on onboarding path",
         %{conn: conn, user: user} do
      assert {:error, {:live_redirect, %{to: @onboarding_path}}} =
               conn |> log_in_user(user) |> live(@home_path)
    end

    test "redirects to sign in if user is unauthenticated", %{conn: conn} do
      user_session_path = Routes.user_session_path(conn, :new)

      assert {:error, {:redirect, %{to: ^user_session_path}}} = conn |> live(@home_path)
    end
  end
end
