defmodule PicselloWeb.ErrorViewTest do
  use PicselloWeb.ConnCase, async: true

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  test "renders 404.html" do
    page = render_to_string(PicselloWeb.ErrorView, "404_page.html", [])
    assert String.contains?(page, "Whoops! We lost that page in our camera bag.")
  end

  test "renders 500.html" do
    page = render_to_string(PicselloWeb.ErrorView, "500_page.html", [])
    assert String.contains?(page, "Something went wrong…")
  end
end
