defmodule PicselloWeb.CalendarFeedControllerTest do
  use PicselloWeb.ConnCase, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  alias PicselloWeb.UserAuth

  setup do
    ExVCR.Config.filter_request_headers("Authorization")
    ExVCR.Config.filter_request_options("basic_auth")

    %{user: insert(:user) |> onboard!, password: valid_user_password()}
  end

  describe "Calendar Feed" do
    test "Requires user to be logged in", %{conn: conn} do
      path = Routes.calendar_feed_path(conn, :index)
      conn = get(conn, path)
      assert html_response(conn, 302)
    end

    @tag :skip
    test "renders calendar feed", %{conn: conn, user: user} do
      conn = UserAuth.log_in_user(conn, user)
      path = Routes.calendar_feed_path(conn, :index)

      conn = get(conn, path)
      assert html_response(conn, 200)
    end
  end
end
