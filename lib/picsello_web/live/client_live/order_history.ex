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
  def handle_params(params, _, socket) do
    socket
    |> is_mobile(params)
    |> noreply()
  end

  @impl true
  def handle_event("back_to_navbar", _, %{assigns: %{is_mobile: is_mobile}} = socket) do
    socket |> assign(:is_mobile, !is_mobile) |> noreply
  end

  @impl true
  def handle_event(
        "order-detail",
        %{"order_number" => order_number},
        socket
      ) do
    %{gallery: gallery} = Orders.get_order_from_order_number(order_number)

    socket
    |> push_redirect(
      to:
        Routes.order_detail_path(socket, :transactions, gallery.id, order_number, %{
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
    client = clients |> Enum.find(&(&1.id == to_integer(id)))

    socket
    |> open_modal(ImportWizard, %{
      current_user: current_user,
      selected_client: client,
      step: :job_details
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "import-job",
        %{"id" => _id},
        %{assigns: %{client: client, current_user: current_user}} = socket
      ) do
    socket
    |> open_modal(ImportWizard, %{
      current_user: current_user,
      selected_client: client,
      step: :job_details
    })
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
    Enum.reduce(jobs, [], fn %{galleries: galleries}, acc ->
      acc ++ Enum.reduce(galleries, [], &(&2 ++ &1.orders))
    end)
  end

  defp get_client(%{assigns: %{current_user: user}} = socket, id) do
    case Clients.get_client(user, [id: id]) do
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
