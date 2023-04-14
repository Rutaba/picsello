defmodule PicselloWeb.Live.Admin.SubscriptionPricing do
  @moduledoc "modify state of sync subscriptiong pricing"
  use PicselloWeb, live_view: [layout: false]
  alias Picsello.{Subscriptions, SubscriptionPlan, Repo, SubscriptionPlansMetadata}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_pricing_rows()
    |> assign_pricing_metadata()
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
      <h2 class="text-2xl font-bold px-6 pb-6">Active Subscription Pricing</h2>
      <div class="grid grid-cols-4 gap-4 items-center px-6 pb-6">
        <div class="col-start-1 font-bold">Stripe Price Id</div>
        <div class="col-start-2 font-bold">Price</div>
        <div class="col-start-3 font-bold">Interval</div>
        <div class="col-start-4 font-bold">Set price active?</div>
        <%= for(%{price: %{stripe_price_id: stripe_price_id, active: active, id: id, recurring_interval: recurring_interval}, changeset: changeset} <- @pricing_rows) do %>
          <.form :let={f} for={changeset} class="contents" id={"form-#{stripe_price_id}"}>
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
              <button class="flex-1 py-2 text-sm btn-secondary" type="button" phx-click="save_subscription_pricing" phx-value-recurring-interval={recurring_interval} phx-value-id={id} phx-value-active={"#{active}"}>Set active</button>
              <% else %>
              <.badge color={:green}>Current price</.badge>
              <% end %>
            </div>
          </.form>
        <% end %>
      </div>
      <div class="flex items-center justify-between mb-8 px-6 pb-6">
        <div>
          <h3 class="text-2xl font-bold">Active Trial Lengths & Content</h3>
          <p class="text-md">Variable trial lengths for various marketing initiatives</p>
        </div>
        <button class="mb-4 btn-primary" phx-click="add_subscription_metadata">Add code</button>
      </div>
      <div class="grid grid-cols-8 gap-4 gap-y-8 items-center px-6 pb-6">
        <div class="col-start-1 font-bold">Code</div>
        <div class="col-start-2 font-bold">Trial Length (Days)</div>
        <div class="col-start-3 col-span-4 font-bold">Content</div>
        <div class="col-start-7 font-bold text-center">Actions</div>
        <%= for(%{row: %{id: id}, changeset: changeset} <- @pricing_metadata) do %>
          <.form :let={f} for={changeset} phx-change="save_subscription_metadata" class="contents" id={"form-#{id}"}>
            <%= hidden_input f, :id %>
            <div class="col-start-1">
              <%= input f, :code, phx_debounce: 200, class: "w-full" %>
            </div>
            <div class="col-start-2">
              <%= input f, :trial_length, type: :number_input, phx_debounce: 200, class: "w-full" %>
            </div>
            <div class="col-start-3 col-span-4">
              <div class="flex items-center gap-10 mb-2">
                <label class="font-bold shrink-0 w-1/4">Signup Title</label>
                <%= input f, :signup_title, phx_debounce: 200, class: "w-3/4" %>
              </div>
              <div class="flex items-center gap-10 mb-2">
                <label class="font-bold shrink-0 w-1/4">Signup Description</label>
                <%= input f, :signup_description, phx_debounce: 200, class: "w-3/4" %>
              </div>
              <div class="flex items-center gap-10 mb-2">
                <label class="font-bold shrink-0 w-1/4">Onboarding Title</label>
                <%= input f, :onboarding_title, phx_debounce: 200, class: "w-3/4" %>
              </div>
              <div class="flex items-center gap-10 mb-2">
                <label class="font-bold shrink-0 w-1/4">Onboarding Description</label>
                <%= input f, :onboarding_description, phx_debounce: 200, class: "w-3/4" %>
              </div>
              <div class="flex items-center gap-10 mb-2">
                <label class="font-bold shrink-0 w-1/4">Success Title</label>
                <%= input f, :success_title, phx_debounce: 200, class: "w-3/4" %>
              </div>
            </div>
            <div class="col-start-7 flex flex-col items-center justify-center">
              <div class="mb-8">
                <%= checkbox(f, :active, class: "w-5 h-5 mr-2.5 checkbox cursor-pointer") %>
                <label>Set code active?</label>
              </div>
              <div>
                <button type="button" class="mb-4 btn-secondary block py-1 px-2 border-red-sales-300 text-red-sales-300" phx-click="delete_subscription_metadata" phx-value-id={id}>Delete code</button>
              </div>
            </div>
          </.form>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event(
        "save_subscription_pricing",
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

  def handle_event(
        "save_subscription_metadata",
        params,
        socket
      ) do
    socket
    |> update_subscription_metadata_row(params, fn row, params ->
      case row |> SubscriptionPlansMetadata.changeset(params) |> Repo.update() do
        {:ok, row} ->
          %{row: row, changeset: SubscriptionPlansMetadata.changeset(row |> Map.from_struct())}

        {:error, changeset} ->
          %{row: row, changeset: changeset}
      end
    end)
    |> noreply()
  end

  def handle_event(
        "add_subscription_metadata",
        _,
        socket
      ) do
    socket
    |> add_subscription_metadata_row()
    |> noreply()
  end

  def handle_event(
        "delete_subscription_metadata",
        %{"id" => id} = _params,
        socket
      ) do
    socket
    |> delete_subscription_metadata_row(id)
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

  defp update_subscription_metadata_row(
         %{assigns: %{pricing_metadata: pricing_metadata}} = socket,
         %{"subscription_plans_metadata" => %{"id" => id} = params},
         f
       ) do
    id = String.to_integer(id)

    socket
    |> assign(
      pricing_metadata:
        Enum.map(pricing_metadata, fn
          %{row: %{id: ^id} = row} ->
            f.(
              row,
              Map.drop(params, ["id"])
            )

          pricing_metadata ->
            pricing_metadata
        end)
    )
  end

  defp delete_subscription_metadata_row(
         %{assigns: %{pricing_metadata: pricing_metadata}} = socket,
         id
       ) do
    id = String.to_integer(id)

    Enum.filter(pricing_metadata, fn %{row: row} -> row.id === id end)
    |> List.first()
    |> Map.get(:row)
    |> Repo.delete()

    socket
    |> assign_pricing_metadata()
  end

  defp add_subscription_metadata_row(socket) do
    SubscriptionPlansMetadata.changeset(%SubscriptionPlansMetadata{}, %{
      code: Enum.random(100_000..999_999) |> to_string,
      trial_length: 60,
      active: false,
      signup_title: "Enter content…",
      signup_description: "Enter content…",
      onboarding_title: "Enter content…",
      onboarding_description: "Enter content…",
      success_title: "Enter content…"
    })
    |> Repo.insert()

    socket
    |> assign_pricing_metadata()
  end

  defp assign_pricing_rows(socket) do
    socket
    |> assign(
      pricing_rows:
        Subscriptions.all_subscription_plans()
        |> Enum.map(&%{price: &1, changeset: SubscriptionPlan.changeset(&1 |> Map.from_struct())})
    )
  end

  defp assign_pricing_metadata(socket) do
    socket
    |> assign(
      pricing_metadata:
        Subscriptions.all_subscription_plans_metadata()
        |> Enum.map(
          &%{
            row: &1,
            changeset: SubscriptionPlansMetadata.changeset(&1 |> Map.from_struct())
          }
        )
    )
  end
end
