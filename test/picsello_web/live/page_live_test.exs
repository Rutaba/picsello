defmodule PicselloWeb.PageLiveTest do
  use PicselloWeb.ConnCase

  import Phoenix.LiveViewTest

  test "disconnected and connected render", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/")
    assert disconnected_html =~ "Welcome to Picsello!"
    assert render(page_live) =~ "Welcome to Picsello!"
  end
end
