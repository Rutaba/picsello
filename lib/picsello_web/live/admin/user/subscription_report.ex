defmodule PicselloWeb.Live.Admin.User.SubscriptionReport do
  @moduledoc "report to check stripe subscription status and compare to ours"
  alias Picsello.Accounts
  use PicselloWeb, live_view: [layout: false]

  import PicselloWeb.LayoutView,
    only: [
      flash: 1
    ]

  require Logger

  alias Picsello.{
    Repo,
    Subscriptions,
    Payments,
    Accounts.User
  }

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_all_users()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= flash(@flash) %>
    <header class="p-8 bg-gray-100 flex items-center justify-between">
      <div>
        <h1 class="text-4xl font-bold">User Subscription Reconciliation Report</h1>
        <p>If the two statuses don't match after your check, need to sync stripe to our db for that user</p>
        <p>Stripe has strict rate limits so wasn't able to preload all the statuses :/</p>
      </div>
    </header>
    <div class="w-screen text-xs">
      <table class="border-2 w-full table-auto">
        <thead>
          <tr class="border-2 text-left">
            <th>Index - Photog ID</th>
            <th>Photog Name</th>
            <th>Photog Email</th>
            <th>Photog Stripe Customer id</th>
            <th>Photog Stripe Subscription id</th>
            <th>Photog Sub Stripe (from stripe) Status</th>
            <th>Photog Sub (our table) Status</th>
          </tr>
        </thead>
        <tbody>
          <%= for({%{user: %{email: email, name: name, id: id, stripe_customer_id: stripe_customer_id, subscription: subscription}, stripe_subscription: stripe_subscription}, index} <- @users |> Enum.with_index()) do %>
            <tr class="w-full ">
              <td class="py-1"><%= index %> - <%= id %></td>
              <td class="py-1"><%= name %></td>
              <td class="py-1"><%= email %></td>
              <td class="py-1">
                <%= if is_nil(stripe_customer_id) do %>
                  -
                <% else %>
                  <a class="link" target="_blank" href={"https://dashboard.stripe.com/customers/#{stripe_customer_id}"}><%= stripe_customer_id %></a>
                <% end %>
              </td>
              <td class="py-1">
                <%= if is_nil(subscription) do %>
                  -
                <% else %>
                  <a class="link" target="_blank" href={"https://dashboard.stripe.com/subscriptions/#{Map.get(subscription, :stripe_subscription_id)}"}><%= Map.get(subscription, :stripe_subscription_id) %></a>
                <% end %>
              </td>
              <td class="py-1">
                <%= if is_nil(subscription) do %>
                  -
                <% else %>
                  <button class="rounded-lg px-2 py-1 bg-gray-200" type="button" phx-click="sync" phx-value-id={Map.get(subscription, :stripe_subscription_id)} phx-value-user_id={id}>Sync</button>
                  <%= if is_nil(stripe_subscription) do %>
                    <button class="rounded-lg px-2 py-1 bg-black text-white ml-4" type="button" phx-click="check" phx-value-id={Map.get(subscription, :stripe_subscription_id)} phx-value-user_id={id}>Check</button>
                  <% else %>
                    <span class="ml-4"><%= Map.get(stripe_subscription, :status) %></span>
                  <% end %>
                <% end %>
              </td>
              <td class="py-1"><%= if is_nil(subscription), do: "-", else: Map.get(subscription, :status)  %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  @impl true
  def handle_event(
        "check",
        %{"id" => id, "user_id" => user_id},
        %{assigns: %{users: users}} = socket
      ) do
    Logger.info("check #{id}")

    socket
    |> assign(
      :users,
      Enum.map(users, fn %{user: user} = user_map ->
        if user.id == String.to_integer(user_id) do
          %{
            user: user,
            stripe_subscription: retrieve_subscription(id)
          }
        else
          user_map
        end
      end)
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "sync",
        %{"id" => id, "user_id" => user_id},
        %{assigns: %{users: users}} = socket
      ) do
    Logger.info("sync #{id}")

    subscription = retrieve_subscription(id)

    case Subscriptions.handle_stripe_subscription(subscription) do
      {:ok, _} ->
        Logger.info("synced #{id}")

        socket
        |> put_flash(:success, "Synced #{id}")
        |> assign(
          :users,
          Enum.map(users, fn %{user: user} = user_map ->
            if user.id == String.to_integer(user_id) do
              %{
                user: Accounts.get_user!(user.id) |> Repo.preload(:subscription),
                stripe_subscription: retrieve_subscription(id)
              }
            else
              user_map
            end
          end)
        )
        |> noreply()

      {:error, error} ->
        Logger.error("Error syncing subscription admin panel: #{inspect(error)}")

        socket
        |> put_flash(:error, "Error syncing #{id}. Check server logs for error")
        |> noreply()
    end
  end

  defp assign_all_users(socket) do
    users =
      Repo.all(User)
      |> Repo.preload(:subscription)
      |> Enum.map(fn user ->
        %{
          user: user,
          stripe_subscription: nil
        }
      end)

    socket
    |> assign(:users, users)
  end

  defp retrieve_subscription(subscription_id) do
    case Payments.retrieve_subscription(subscription_id, []) do
      {:ok, subscription} ->
        subscription

      {:error, error} ->
        Logger.error("Error retrieving subscription: #{inspect(error)}")
        nil
    end
  end
end
