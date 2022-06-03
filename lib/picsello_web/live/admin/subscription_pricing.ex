defmodule PicselloWeb.Live.Admin.SubscriptionPricing do
  @moduledoc "modify state of sync subscriptiong pricing"
  use PicselloWeb, live_view: [layout: false]
  alias Picsello.{Subscriptions, SubscriptionPlan, Repo}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_pricing_rows()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="p-8 bg-gray-100">
      <h1 class="text-4xl font-bold">Manage Subscription Pricing</h1>
      <p class="mt-4">Please make sure you have already synced your pricing changes from Stripe before modifying the active state below. <%= live_redirect "Go here to sync.", to: Routes.admin_workers_path(@socket, :index), class: "text-blue-planning-300 underline" %></p>
    </header>
    <div class="p-4">
      <div class="grid grid-cols-4 gap-2 items-center px-6 pb-6">
        <div class="col-start-1 font-bold">Stripe Price Id</div>
        <div class="col-start-2 font-bold">Price</div>
        <div class="col-start-3 font-bold">Interval</div>
        <div class="col-start-4 font-bold">Set price active?</div>
        <%= for(%{price: %{stripe_price_id: stripe_price_id, active: active, id: id, recurring_interval: recurring_interval}, changeset: changeset} <- @pricing_rows) do %>
          <.form let={f} for={changeset} class="contents" id={"form-#{stripe_price_id}"}>
            <%= hidden_input f, :id %>
            <div class="col-start-1">
              <%= input f, :stripe_price_id, phx_debounce: 200, disabled: true, class: "w-full" %>
            </div>
            <div class="col-start-2">
              <%= input f, :price, phx_debounce: 200, disabled: true, class: "w-full" %>
            </div>
            <div class="col-start-3">
              <%= input f, :recurring_interval, phx_debounce: 200, disabled: true, class: "w-full" %>
            </div>
            <div class="col-start-4">
              <%= if !active do %>
              <button class="flex-1 py-2 text-sm btn-secondary" type="button" phx-click="save" phx-value-recurring-interval={recurring_interval} phx-value-id={id} phx-value-active={"#{active}"}>Set active</button>
              <% else %>
              <.badge color={:green}>Current price</.badge>
              <% end %>
            </div>
          </.form>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event(
        "save",
        params,
        socket
      ) do
    socket
    |> update_pricing_row(params, fn price, params ->
      case price |> SubscriptionPlan.changeset(params) |> Repo.update() do
        {:ok, price} ->
          %{price: price, changeset: SubscriptionPlan.changeset(price |> Map.from_struct())}

        {:error, changeset} ->
          %{price: price, changeset: changeset}
      end
    end)
    |> noreply()
  end

  defp update_pricing_row(
         %{assigns: %{pricing_rows: pricing_rows}} = socket,
         %{"id" => id, "recurring-interval" => recurring_interval} = params,
         f
       ) do
    id = String.to_integer(id)

    socket
    |> assign(
      pricing_rows:
        Enum.map(pricing_rows, fn
          %{price: %{recurring_interval: ^recurring_interval} = price} ->
            f.(
              price,
              Map.replace(params, "active", price.id === id)
            )

          pricing_row ->
            pricing_row
        end)
    )
  end

  defp assign_pricing_rows(socket) do
    socket
    |> assign(
      pricing_rows:
        Subscriptions.all_subscription_plans()
        |> Enum.map(&%{price: &1, changeset: SubscriptionPlan.changeset(&1 |> Map.from_struct())})
    )
  end
end
