defmodule PicselloWeb.Live.Admin.Index do
  @moduledoc false
  use PicselloWeb, live_view: [layout: false]

  @impl true
  def render(assigns) do
    ~H"""
    <header class="p-8 bg-gray-100">
      <h1 class="text-4xl font-bold">Picsello Admin</h1>
    </header>
    <div class="p-8">
      <ul class="mt-4 flex grid gap-10 grid-cols-1 sm:grid-cols-4">
        <li><%= live_redirect "Performance Dashboard", to: Routes.live_dashboard_path(@socket, :home), class: "border flex items-center justify-center rounded-lg p-8 font-bold text-blue-planning-300" %></li>

        <li><%= live_redirect "Product Category Configuration", to: Routes.admin_categories_path(@socket, :index), class: "border flex items-center justify-center rounded-lg p-8 font-bold text-blue-planning-300" %></li>

        <li><%= live_redirect "Run Jobs", to: Routes.admin_workers_path(@socket, :index), class: "border flex items-center justify-center rounded-lg p-8 font-bold text-blue-planning-300" %></li>

        <li><%= live_redirect "Pricing Calculator Configuration", to: Routes.admin_pricing_calculator_path(@socket, :index), class: "border flex items-center justify-center rounded-lg p-8 font-bold text-blue-planning-300" %></li>

        <li><%= live_redirect "Subscription Pricing", to: Routes.admin_subscription_pricing_path(@socket, :index), class: "border flex items-center justify-center rounded-lg p-8 font-bold text-blue-planning-300" %></li>
      </ul>
    </div>
    """
  end
end
