defmodule PicselloWeb.JobLive.Transaction.OrderDetail do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Cart, Job, Repo, Galleries, Orders}
  require Ecto.Query
  import PicselloWeb.GalleryLive.Shared, only: [bundle_image: 1]
  import PicselloWeb.JobLive.Shared, only: [redirect_to_stripe: 1]

  @impl true
  def mount(%{"id" => job_id, "order_number" => order_number}, _session, %{assigns: %{live_action: action}} = socket) do
    gallery = Galleries.get_gallery_by_job_id(job_id) |> Repo.preload(job: [:client])
    order = gallery |> Orders.get!(order_number)

    socket
    |> assign(:page_title, action |> Phoenix.Naming.humanize())
    |> assign(:job_id, job_id)
    |> assign(:gallery, gallery)
    |> assign(:order, order)
    |> assign_details()
    |> ok()
  end

  @impl true
  def handle_event("open-stripe", _, socket), do: socket |> redirect_to_stripe()

  @impl true
  def handle_event("view_gallery", _, %{assigns: %{gallery: gallery}} = socket),
    do:
      socket
      |> push_redirect(to: Routes.gallery_photographer_index_path(socket, :index, gallery.id))
      |> noreply()

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

  defp assign_details(%{assigns: %{current_user: current_user, order: order}} = socket) do
    socket
    |> assign(
      organization_name: current_user.organization.name,
      shipping_address: order.delivery_info.address,
      shipping_name: order.delivery_info.name
    )
  end

  defdelegate total_cost(order), to: Cart
  defdelegate item_image_url(item), to: Cart
  defdelegate product_name(order), to: Cart
  defdelegate quantity(item), to: Cart.Product
  defdelegate price_display(product), to: Cart
end
