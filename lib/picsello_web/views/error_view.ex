defmodule PicselloWeb.ErrorView do
  use PicselloWeb, :view
  import PicselloWeb.LiveHelpers, only: [icon: 1]
  import PicselloWeb.LayoutView, only: [help_chat_widget: 1]

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  def render("404.html", assigns) do
    Phoenix.View.render_layout PicselloWeb.LayoutView, "root.html", assigns do
      render("404_page.html", assigns)
    end
  end

  def render("403.html", assigns) do
    Phoenix.View.render_layout PicselloWeb.LayoutView, "root.html", assigns do
      render("403_page.html", assigns)
    end
  end

  def render("500.html", assigns) do
    Phoenix.View.render_layout PicselloWeb.LayoutView, "root.html", assigns do
      render("500_page.html", assigns)
    end
  end

  def render("500.json", _assigns) do
    Jason.encode!(%{code: 500, message: "Something went wrong…"})
  end
end
