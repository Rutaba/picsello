defmodule PicselloWeb.ErrorView do
  use PicselloWeb, :view

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  def render("404.html", assigns) do
    Phoenix.View.render_layout PicselloWeb.LayoutView, "root.html", assigns do
      render("404_page.html", assigns)
    end
  end

  def render("500.html", assigns) do
    Phoenix.View.render_layout PicselloWeb.LayoutView, "root.html", assigns do
      render("500_page.html", assigns)
    end
  end
end
