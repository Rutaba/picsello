defmodule PicselloWeb.Live.FinanceSettings do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.User.Settings, only: [settings_nav: 1]

  @impl true
  def mount(_params, _session, %{assigns: %{current_user: _user}} = socket) do
    socket
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
              <button type="button" phx-click="render-stripe-account" class="px-8 text-center btn-primary">Go to Stripe account</button>
            </div>
          </.card>
        </div>
      </div>
    </.settings_nav>
    """
  end

  def card(assigns) do
    assigns = Enum.into(assigns, %{class: ""})

    ~H"""
    <div class={"flex overflow-hidden border rounded-lg #{@class}"}>
      <div class="w-4 border-r bg-blue-planning-300" />

      <div class="flex flex-col justify-between w-full p-4">
        <h1 class="mb-2 text-xl font-bold sm:text-2xl text-blue-planning-300"><%= @title %></h1>

        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end
end
