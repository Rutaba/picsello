defmodule PicselloWeb.Live.Admin.Index do
  @moduledoc false
  use PicselloWeb, live_view: [layout: false]

  @impl true
  def render(assigns) do
    ~H"""
    <header class="p-8 bg-gray-100">
      <h1 class="text-4xl font-bold">Picsello Admin</h1>
    </header>
    <nav class="p-8">
      <ul class="mt-4 font-bold grid gap-10 grid-cols-1 sm:grid-cols-4 text-blue-planning-300">
        <li><%= live_redirect "Performance Dashboard", to: Routes.live_dashboard_path(@socket, :home), class: "border flex items-center justify-center rounded-lg p-8" %></li>

        <li><%= live_redirect "Product Category Configuration", to: Routes.admin_categories_path(@socket, :index), class: "border flex items-center justify-center rounded-lg p-8" %></li>

        <li><%= live_redirect "Run Jobs", to: Routes.admin_workers_path(@socket, :index), class: "border flex items-center justify-center rounded-lg p-8" %></li>

        <li><%= live_redirect "Smart Profit Calculator™ Configuration", to: Routes.admin_pricing_calculator_path(@socket, :index), class: "border flex items-center justify-center rounded-lg p-8" %></li>

        <li><%= live_redirect "Next Up Cards Admin", to: Routes.admin_next_up_cards_path(@socket, :index), class: "border flex items-center justify-center rounded-lg p-8" %></li>

        <li><%= live_redirect "Manage Users", to: Routes.admin_user_index_path(@socket, :index), class: "border flex items-center justify-center rounded-lg p-8" %></li>

        <li><%= live_redirect "Subscription Pricing", to: Routes.admin_subscription_pricing_path(@socket, :index), class: "border flex items-center justify-center rounded-lg p-8" %></li>

        <li><%= live_redirect "Product Pricing Report", to: Routes.admin_product_pricing_path(@socket, :index), class: "border flex items-center justify-center rounded-lg p-8" %></li>
        <li>
          <div class="grid border flex items-center justify-center rounded-lg py-4 px-8">
            Current photo Uploaders
            <div class="flex items-center justify-center text-red-500 pt-2">
              <%= PicselloWeb.UploaderCache.current_uploaders() %>
            </div>
          </div>
        </li>
      </ul>
    </nav>
    """
  end
end
