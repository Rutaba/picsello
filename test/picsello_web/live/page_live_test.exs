defmodule PicselloWeb.PageLiveTest do
  use PicselloWeb.ConnCase

  import Phoenix.LiveViewTest

  test "disconnected and connected render", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/")
    assert disconnected_html =~ "Sign Up"
    assert render(page_live) =~ "Sign Up"
  end
end
