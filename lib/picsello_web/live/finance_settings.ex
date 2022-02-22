defmodule PicselloWeb.Live.FinanceSettings do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.User.Settings, only: [settings_nav: 1, card: 1]

  alias Picsello.Accounts

  @impl true
  def mount(_params, _session, %{assigns: %{current_user: _user}} = socket) do
    socket
    |> add_stripe_button_details()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.settings_nav socket={@socket} live_action={@live_action} current_user={@current_user}>
      <div class="flex flex-col justify-between flex-1 flex-grow-0 mt-5 sm:flex-row">
        <div>
          <h1 class="text-2xl font-bold">Finances</h1>
        </div>
      </div>

      <hr class="my-4 sm:my-10" />

      <div class="flex flex-row justify-between flex-1 flex-grow-0">

        <div class="flex flex-col w-1/2 mr-6">
          <.card title="Sales tax">
            <form id="tax_form">

              <div class="flex flex-col mt-2">
                <label class="flex items-end justify-between mb-1 text-sm font-semibold" field={:sales_tax_rate}>
                  <span>Sales tax rate</span>
                </label>

                <input class="w-full h-12 px-3 mt-2 border border-gray-200 rounded focus:outline-none focus:border-blue-planning-300" id="username" type="number" placeholder="0.0%">
                <div class="flex items-center mt-2">
                <input type="checkbox" class="w-4 h-4 mr-2"/>
                <label class="text-gray-500">
                    Collect digital product tax
                </label>
                </div>
              </div>

              <div class="mt-4 text-right">
                <%= submit "Change tax options", class: "btn-primary mx-1" %>
              </div>
            </form>
          </.card>
        </div>

        <div class="flex flex-row w-1/2">
          <.card title="Stripe Account">
            <p>Picsello uses Stripe so your payments are always secure. View and manage your payments through your Stripe account.</p>
            <div class="text-right">
              <%= button @stripe_button.text, to: @stripe_button.url, method: "get", target: "_blank", class: "px-8 text-center btn-primary" %>
            </div>
          </.card>
        </div>
      </div>
    </.settings_nav>
    """
  end

  def add_stripe_button_details(%{assigns: %{current_user: user}} = socket) do
    stripe_button =
      if Accounts.user_stripe_setup_complete?(user),
        do: %{text: "Go to Stripe account", url: "https://dashboard.stripe.com/"},
        else: %{text: "Set up stripe", url: "/users/settings/stripe-refresh"}

    socket
    |> assign(:stripe_button, stripe_button)
  end
end
