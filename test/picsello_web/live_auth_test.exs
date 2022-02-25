defmodule PicselloWeb.LiveAuthTest do
  use PicselloWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup do
    [user: insert(:user)]
  end

  @home_path Routes.home_path(PicselloWeb.Endpoint, :index)
  @onboarding_path Routes.onboarding_path(PicselloWeb.Endpoint, :index)

  describe "mount :default" do
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

  describe "mount :gallery_client" do
    setup %{conn: conn} do
      gallery = insert(:gallery)

      [
        gallery: gallery,
        show_path: Routes.gallery_client_show_path(conn, :show, gallery.client_link_hash)
      ]
    end

    test "/gallery/:hash with no gallery is 404", %{conn: conn} do
      client_show_path = Routes.gallery_client_show_path(conn, :show, "wrong-hash")

      assert_raise Ecto.NoResultsError, fn ->
        conn |> live(client_show_path)
      end
    end

    # FIXME: need tests around auth behavior on /gallery/:hash/login

    test "/gallery/:hash not authenticated client or user", %{
      conn: conn,
      gallery: gallery,
      show_path: show_path
    } do
      gallery_login_path =
        Routes.gallery_client_show_login_path(conn, :login, gallery.client_link_hash)

      assert {:error, {:live_redirect, %{to: ^gallery_login_path}}} = live(conn, show_path)
    end

    test "/gallery/:hash authenticated photographer, not your gallery" do
      # should show password dialog (302?)
    end

    test "/gallery/:hash authenticated client" do
      # should render gallery (200?)
    end

    test "/gallery/:hash authenticated photographer, your gallery" do
      # should render gallery (200?)
    end
  end
end
