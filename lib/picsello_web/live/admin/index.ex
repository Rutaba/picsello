defmodule PicselloWeb.Live.Admin.Index do
  @moduledoc false
  use PicselloWeb, live_view: [layout: false]

  import PicselloWeb.LayoutView,
    only: [
      admin_banner: 1
    ]

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :class, "border flex items-center justify-center rounded-lg p-8")

    ~H"""
    <header class="p-8 bg-gray-100" phx-hook="showAdminBanner" id="show-admin-banner">
      <h1 class="text-4xl font-bold">Picsello Admin</h1>
      <.admin_banner socket={@socket} />
    </header>
    <nav class="p-8">
      <ul class="mt-4 font-bold grid gap-10 grid-cols-1 sm:grid-cols-4 text-blue-planning-300">
        <li><%= live_redirect "Performance Dashboard", to: Routes.live_dashboard_path(@socket, :home), class: @class %></li>

        <li><%= live_redirect "Product Category Configuration", to: Routes.admin_categories_path(@socket, :index), class: @class %></li>

        <li><%= live_redirect "Run Jobs", to: Routes.admin_workers_path(@socket, :index), class: @class %></li>

        <li><%= live_redirect "Smart Profit Calculator™ Configuration", to: Routes.admin_pricing_calculator_path(@socket, :index), class: @class %></li>

        <li><%= live_redirect "Next Up Cards Admin", to: Routes.admin_next_up_cards_path(@socket, :index), class: @class %></li>

        <li><%= live_redirect "Manage Users", to: Routes.admin_user_index_path(@socket, :index), class: @class %></li>

        <li><%= live_redirect "User Subscription Reconciliation Report", to: Routes.admin_user_subscription_report_path(@socket, :index), class: @class %></li>

        <li><%= live_redirect "Subscription Pricing", to: Routes.admin_subscription_pricing_path(@socket, :index), class: @class %></li>

        <li><%= live_redirect "Product Pricing Report", to: Routes.admin_product_pricing_path(@socket, :index), class: @class %></li>

        <li><%= live_redirect "Manage Shipment Details", to: Routes.admin_shippment_index_path(@socket, :index), class: @class %></li>

        <li><%= live_redirect "Automations Report Index", to: Routes.admin_automations_report_index_path(@socket, :index), class: @class %></li>

        <li>
          <div class="grid border flex items-center justify-center rounded-lg py-4 px-8">
            Current photo Uploaders
            <div class="flex items-center justify-center text-red-500 pt-2">
              <%= PicselloWeb.UploaderCache.current_uploaders() %>
            </div>
          </div>
        </li>

        <li><%= live_redirect "Manage Admin Global Settings", to: Routes.admin_global_settings_path(@socket, :index), class: @class %></li>

        <li><%= live_redirect "WHCC Orders report", to: Routes.admin_whcc_orders_report_path(@socket, :index), class: @class %></li>

        <li><%= live_redirect "Feature Flags", to: "/feature-flags", class: @class %></li>
        <li><%= live_redirect "Manage Automated Emails", to: Routes.admin_automated_emails_path(@socket, :index), class: @class %></li>
      </ul>
    </nav>
    """
  end
end
