defmodule PicselloWeb.Live.ClientLive.OrderHistory do
  @moduledoc false

  use PicselloWeb, :live_view
  import PicselloWeb.Live.ClientLive.Shared

  alias PicselloWeb.JobLive.ImportWizard
  alias Picsello.{Cart.Order, Repo, Clients, Orders}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    socket
    |> get_client(id)
    |> assign(:arrow_show, "contact details")
    |> assign_client_orders(id)
    |> ok()
  end

  @impl true
  def handle_event(
        "order-detail",
        %{"order_number" => order_number},
        socket
      ) do
    order = Orders.get_order_from_order_number(order_number)
    job = Map.get(order.gallery, :job)

    socket
    |> push_redirect(
      to:
        Routes.order_detail_path(socket, :transactions, job.id, order_number, %{
          "request_from" => "order_history"
        })
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "import-job",
        %{"id" => id},
        %{assigns: %{clients: clients, current_user: current_user}} = socket
      ) do
    id = String.to_integer(id)
    client = clients |> Enum.find(&(&1.id == id))

    assigns = %{
      current_user: current_user,
      selected_client: client,
      step: :job_details
    }

    socket
    |> open_modal(ImportWizard, assigns)
    |> noreply()
  end

  @impl true
  def handle_event(
        "import-job",
        %{"id" => _id},
        %{assigns: %{client: client, current_user: current_user}} = socket
      ) do
    assigns = %{
      current_user: current_user,
      selected_client: client,
      step: :job_details
    }

    socket
    |> open_modal(ImportWizard, assigns)
    |> noreply()
  end

  @impl true
  def handle_event(
        "open-stripe",
        _,
        %{assigns: %{client: client, current_user: current_user}} = socket
      ) do
    socket
    |> redirect(
      external:
        "https://dashboard.stripe.com/#{current_user.organization.stripe_account_id}/customers/#{client.stripe_customer_id}"
    )
    |> noreply()
  end

  defp assign_client_orders(socket, client_id) do
    client = Clients.get_client_orders_query(client_id) |> Repo.one()
    orders = filter_client_orders(client.jobs)

    socket
    |> assign(orders: orders)
  end

  defp filter_client_orders(jobs) do
    jobs
    |> Enum.filter(fn %{gallery: gallery} -> not is_nil(gallery) and Enum.any?(gallery.orders) end)
    |> Enum.reduce([], fn job, acc ->
      acc ++ job.gallery.orders
    end)
  end

  defp get_client(%{assigns: %{current_user: user}} = socket, id) do
    case Clients.get_client(id, user) do
      nil ->
        socket |> redirect(to: "/clients")

      client ->
        socket |> assign(:client, client) |> assign(:client_id, client.id)
    end
  end

  def order_date(time_zone, order) do
    if is_nil(order.placed_at), do: nil, else: strftime(time_zone, order.placed_at, "%m/%d/%Y")
  end

  def order_status(order) do
    order_intent = Map.get(order, :intent)

    cond do
      is_nil(order_intent) and Enum.empty?(order.digitals) and is_nil(order.placed_at) ->
        "Failed Payment"

      order.placed_at ->
        "Completed"

      true ->
        "Pending"
    end
  end
end
