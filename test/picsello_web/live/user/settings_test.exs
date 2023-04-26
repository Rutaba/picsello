defmodule PicselloWeb.Live.User.SettingsTest do
  use PicselloWeb.ConnCase, async: true

  alias Picsello.Accounts
  import Phoenix.LiveViewTest

  @endpoint PicselloWeb.Endpoint

  setup :register_and_log_in_user

  setup do
    Mox.stub_with(Picsello.MockPayments, Picsello.StripePayments)
    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)
    :ok
  end

  def sandbox_allow(%{pid: pid} = view) do
    Picsello.Sandbox.allow(Picsello.Repo, self(), pid)
    view
  end

  describe "GET /users/settings" do
    test "renders settings page", %{conn: conn} do
      {:ok, _view, html} = live(conn, Routes.user_settings_path(conn, :edit))
      assert html =~ "Settings"
    end

    test "redirects if user is not logged in" do
      conn = build_conn()
      conn = get(conn, Routes.user_settings_path(conn, :edit))
      assert redirected_to(conn) == Routes.user_session_path(conn, :new)
    end

    test "does not show email/password forms if user signed up via google", %{
      conn: conn,
      user: user
    } do
      user
      |> Ecto.Changeset.cast(%{sign_up_auth_provider: :google}, [:sign_up_auth_provider])
      |> Picsello.Repo.update!()

      {:ok, _view, html} = live(conn, Routes.user_settings_path(conn, :edit))

      assert ["update_name", "update_time_zone", "update_phone"] =
               html
               |> Floki.parse_fragment!()
               |> Floki.attribute("input[name='action']", "value")
    end
  end

  describe "change password form" do
    test "updates the user password and resets tokens", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, Routes.user_settings_path(conn, :edit))

      form =
        view
        |> form("form[action='/users/settings']", %{
          action: "update_password",
          _method: "put",
          user: %{password_to_change: valid_user_password(), password: "new valid password"}
        })

      form |> render_submit()

      new_password_conn = form |> follow_trigger_action(conn)

      assert redirected_to(new_password_conn) == Routes.user_settings_path(conn, :edit)
      assert get_session(new_password_conn, :user_token) != get_session(conn, :user_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "does not update password on invalid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, Routes.user_settings_path(conn, :edit))

      response =
        view
        |> form("form[action='/users/settings']", %{
          action: "update_password",
          _method: "put",
          user: %{password_to_change: "invalid", password: "too short"}
        })
        |> render_submit()

      assert response =~ "Settings</h1>"
      assert response =~ "should be at least 12 characters"
      assert response =~ "is not valid"
    end
  end

  describe "submit change email form" do
    setup %{conn: conn} do
      {:ok, view, _html} = conn |> live(Routes.user_settings_path(conn, :edit))
      [view: view |> sandbox_allow()]
    end

    @tag :capture_log
    test "updates the user email", %{view: view, user: user} do
      view
      |> render_submit("save", %{
        "action" => "update_email",
        "user" => %{
          "email" => unique_user_email(),
          "current_password" => valid_user_password()
        }
      })

      assert view |> has_element?("*[title='info']", "A link to confirm your email")
      assert_receive {:delivered_email, email}
      assert %{"url" => _url} = email |> email_substitutions()
      assert Accounts.get_user_by_email(user.email)
    end

    test "does not update email on invalid data", %{view: view, user: user} do
      html =
        view
        |> render_submit("save", %{
          "action" => "update_email",
          "user" => %{"email" => user.email, "current_password" => "wrong password"}
        })

      assert html =~ "is not valid"
      assert html =~ "did not change"
    end
  end
end
