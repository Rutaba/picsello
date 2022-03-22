defmodule PicselloWeb.Live.Admin.Index do
  @moduledoc false
  use PicselloWeb, live_view: [layout: false]

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4">
      <h1 class="text-xl">Admin</h1>

      <ul class="mt-4">
        <li><%= live_redirect "performance dashboard", to: Routes.live_dashboard_path(@socket, :home) %></li>

        <li><%= live_redirect "product category configuration", to: Routes.admin_categories_path(@socket, :index) %></li>

        <li><%= live_redirect "run jobs", to: Routes.admin_workers_path(@socket, :index) %></li>
      </ul>
    </div>
    """
  end
end
