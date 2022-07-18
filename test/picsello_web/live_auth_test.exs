defmodule PicselloWeb.LiveAuthTest do
  use PicselloWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Picsello.Galleries

  setup do
    [plan | _] = insert_subscription_plans!()

    [user: insert(:user), plan: plan]
  end

  @expired -7 * 24 * 60 * 60
  @home_path Routes.home_path(PicselloWeb.Endpoint, :index)
  @onboarding_path Routes.onboarding_path(PicselloWeb.Endpoint, :index)
  @jobs_path Routes.job_path(PicselloWeb.Endpoint, :jobs)

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

    test "redirects to home if user is authenticated, onboarded and subscription is expired", %{
      user: user,
      plan: plan,
      conn: conn
    } do
      insert(:subscription_event, user: user, subscription_plan: plan, status: "canceled")

      assert {:error, {:live_redirect, %{to: @home_path}}} =
               conn |> log_in_user(user |> onboard!()) |> live(@jobs_path)
    end

    test "redirects to sign in if user is unauthenticated", %{conn: conn} do
      user_session_path = Routes.user_session_path(conn, :new)

      assert {:error, {:redirect, %{to: ^user_session_path}}} = conn |> live(@home_path)
    end
  end

  describe "mount :gallery_client" do
    setup %{conn: conn} do
      {conn, user, gallery} = build_defaults(conn)

      [
        conn: conn,
        gallery: gallery,
        user: user,
        show_path: Routes.gallery_client_index_path(conn, :index, gallery.client_link_hash)
      ]
    end

    test "/gallery/:hash with no gallery is 404", %{conn: conn} do
      client_show_path = Routes.gallery_client_index_path(conn, :index, "wrong-hash")

      assert_raise Ecto.NoResultsError, fn ->
        conn |> live(client_show_path)
      end
    end

    test "/gallery/:hash authenticate gallery expiry", %{conn: conn} do
      expired_at = DateTime.utc_now() |> DateTime.add(@expired)
      user = insert(:user)
      gallery = insert(:gallery, expired_at: expired_at, job: insert(:lead, user: user))
      show_path = Routes.gallery_client_index_path(conn, :index, gallery.client_link_hash)
      to = "/gallery-expired/" <> gallery.client_link_hash

      assert {:error, {:live_redirect, %{flash: %{}, to: ^to}}} = live(conn, show_path)
    end

    test "/gallery/:hash authenticate subscription is expired", %{
      user: user,
      plan: plan,
      conn: conn
    } do
      insert(:subscription_event, user: user, subscription_plan: plan, status: "canceled")
      gallery = insert(:gallery, job: insert(:lead, user: user))

      show_path = Routes.gallery_client_index_path(conn, :index, gallery.client_link_hash)
      to = "/gallery-expired/" <> gallery.client_link_hash

      assert {:error, {:live_redirect, %{flash: %{}, to: ^to}}} = live(conn, show_path)
    end

    test "/gallery/:hash not authenticated client or user", %{
      conn: conn,
      gallery: gallery,
      show_path: show_path
    } do
      gallery_login_path =
        Routes.gallery_client_show_login_path(conn, :gallery_login, gallery.client_link_hash)

      assert {:error, {:live_redirect, %{to: ^gallery_login_path}}} = live(conn, show_path)
    end

    test "/gallery/:hash authenticated photographer, not your gallery", %{
      conn: conn,
      gallery: gallery,
      show_path: show_path
    } do
      user = insert(:user)

      gallery_login_path =
        Routes.gallery_client_show_login_path(conn, :gallery_login, gallery.client_link_hash)

      assert {:error, {:live_redirect, %{flash: %{}, to: ^gallery_login_path}}} =
               conn
               |> log_in_user(onboard!(user))
               |> live(show_path)
    end

    test "/gallery/:hash authenticated client", %{
      conn: conn,
      gallery: gallery,
      show_path: show_path
    } do
      {:ok, token} = Galleries.build_gallery_session_token(gallery, gallery.password)

      assert {:ok, _view, _html} =
               conn
               |> Plug.Conn.put_session("gallery_session_token", token)
               |> live(show_path)
    end

    test "/gallery/:hash authenticated photographer, your gallery", %{
      conn: conn,
      show_path: show_path,
      user: user
    } do
      assert {:ok, _view, _html} =
               conn
               |> log_in_user(onboard!(user))
               |> live(show_path)
    end

    test "/gallery/:hash?pw=123 already authenticated drops param", %{
      gallery: gallery,
      conn: conn,
      show_path: show_path
    } do
      {:ok, token} = Galleries.build_gallery_session_token(gallery, gallery.password)
      conn = put_session(conn, "gallery_session_token", token)

      assert {:error, {:redirect, %{to: ^show_path}}} = live(conn, show_path <> "?pw=123")
    end

    test "/gallery/:hash?pw=123 correct password stores token in session", %{
      conn: conn,
      gallery: gallery,
      show_path: show_path
    } do
      conn = get(conn, show_path <> "?pw=#{gallery.password}")

      assert Galleries.session_exists_with_token?(
               gallery.id,
               get_session(conn, "gallery_session_token"),
               :gallery
             )
    end

    test "/gallery/:hash?pw=123 incorrect password not authenticated", %{
      conn: conn,
      gallery: gallery,
      show_path: show_path
    } do
      conn = get(conn, show_path <> "?pw=#{gallery.password}123")

      refute Galleries.session_exists_with_token?(
               gallery.id,
               get_session(conn, "gallery_session_token"),
               :gallery
             )
    end
  end

  describe "mount :proofing_album_client" do
    setup %{conn: conn} do
      {conn, user, gallery} = build_defaults(conn)
      album = insert(:proofing_album, %{gallery_id: gallery.id})
      un_protected_album = insert(:proofing_album, %{gallery_id: gallery.id, set_password: false})

      [
        conn: conn,
        user: user,
        un_protected_album: un_protected_album,
        album: album,
        show_path: Routes.gallery_client_index_path(conn, :album, album.client_link_hash)
      ]
    end

    test "/album/:hash authenticated client for protected album", %{
      conn: conn,
      album: album,
      show_path: show_path
    } do
      {:ok, token} = Galleries.build_album_session_token(album, album.password)

      assert {:ok, _view, _html} =
               conn
               |> Plug.Conn.put_session("album_session_token", token)
               |> live(show_path)
    end

    test "/album/:hash not authenticated client or user", %{
      conn: conn,
      album: album,
      show_path: show_path
    } do
      album_login_path =
        Routes.gallery_client_show_login_path(conn, :album_login, album.client_link_hash)

      assert {:error, {:live_redirect, %{to: ^album_login_path}}} = live(conn, show_path)
    end

    test "/album/:hash, show unprotected album without client authentication", %{
      conn: conn,
      un_protected_album: un_protected_album
    } do
      show_path =
        Routes.gallery_client_index_path(conn, :album, un_protected_album.client_link_hash)

      assert {:ok, _view, _html} = live(conn, show_path)
    end

    test "/album/:hash authenticated photographer, your album", %{
      conn: conn,
      show_path: show_path,
      user: user
    } do
      assert {:ok, _view, _html} =
               conn
               |> log_in_user(onboard!(user))
               |> live(show_path)
    end

    test "/album/:hash authenticated photographer, not your album", %{
      conn: conn,
      album: album,
      show_path: show_path
    } do
      user = insert(:user)

      album_login_path =
        Routes.gallery_client_show_login_path(conn, :album_login, album.client_link_hash)

      assert {:error, {:live_redirect, %{flash: %{}, to: ^album_login_path}}} =
               conn
               |> log_in_user(onboard!(user))
               |> live(show_path)
    end

    test "/album/:hash with no album is 404", %{conn: conn} do
      show_path = Routes.gallery_client_index_path(conn, :album, "wrong-hash")

      assert_raise Ecto.NoResultsError, fn ->
        conn |> live(show_path)
      end
    end
  end

  def build_defaults(conn) do
    conn = conn |> Phoenix.ConnTest.init_test_session(%{})
    user = insert(:user)
    job = insert(:lead, type: "wedding", user: user) |> promote_to_job()
    gallery = insert(:gallery, %{name: "Test Client Weeding", job: job})

    {conn, user, gallery}
  end
end
