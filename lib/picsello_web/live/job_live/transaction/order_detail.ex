defmodule PicselloWeb.JobLive.Transaction.OrderDetail do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Cart, Job, Repo, Galleries, Orders}
  require Ecto.Query
  alias Ecto.Query
  import PicselloWeb.JobLive.Shared, only: [assign_job: 2]
  import PicselloWeb.GalleryLive.Shared, only: [bundle_image: 1]


  @impl true
  def mount(%{"id" => job_id, "order_number" => order_number}, _session, %{assigns: %{live_action: action}} = socket) do
    gallery = Galleries.get_gallery_by_job_id(job_id) |> Repo.preload(:job)
    order = gallery |> Orders.get!(order_number)

    socket
    |> assign(:page_title, action |> Phoenix.Naming.humanize())
    |> assign(:job_id, job_id)
    |> assign(:gallery, gallery)
    |> assign(:order, order)
    |> ok()
  end

  @impl true
  def handle_event("order-detail", _, socket) do
    # TODO: will be done in next story
    socket |> noreply()
  end

  @impl true
  def handle_event("open-stripe", _, %{assigns: %{gallery: %{job: job}, current_user: current_user}} = socket) do
    client = job |> Repo.preload(:client) |> Map.get(:client)

    socket
    |> redirect(
      external:
        "https://dashboard.stripe.com/#{current_user.organization.stripe_account_id}/customers/#{client.stripe_customer_id}"
    )
    |> noreply()
  end

  defp order_status(%{intent: %{status: status}}), do: status
  defp order_status(_), do: "processed"

  defp order_date(time_zone, placed_at), do: strftime(time_zone, placed_at, "%m/%d/%Y")

  defp tracking(%{whcc_order: %{orders: sub_orders}}, %{editor_id: editor_id}) do
    Enum.find_value(sub_orders, fn
      %{editor_id: ^editor_id, whcc_tracking: tracking} ->
        tracking

      _ ->
        nil
    end)
  end

  defp tracking_link(assigns) do
    ~H"""
    <%= for %{carrier: carrier, tracking_url: url, tracking_number: tracking_number} <- @info.shipping_info do %>
      <a href={url} target="_blank" class="underline cursor-pointer">
        <%= carrier %>
        <%= tracking_number %>
      </a>
    <% end %>
    """
  end

  defdelegate total_cost(order), to: Cart
  defdelegate item_image_url(item), to: Cart
  defdelegate product_name(order), to: Cart
  defdelegate quantity(item), to: Cart.Product
  defdelegate price_display(product), to: Picsello.Cart
end
