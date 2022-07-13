defmodule PicselloWeb.JobLive.Transaction.OrderDetail do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Repo, Cart, Job, Galleries, Orders}
  require Ecto.Query
  import PicselloWeb.GalleryLive.Shared, only: [order_details: 1]
  import PicselloWeb.JobLive.Shared, only: [assign_job: 2]

  @impl true
  def mount(
        %{"id" => job_id, "order_number" => order_number},
        _session,
        %{assigns: %{live_action: action}} = socket
      ) do
    socket
    |> assign(:page_title, action |> Phoenix.Naming.humanize())
    |> assign_job(job_id)
    |> then(fn socket ->
      gallery = Galleries.get_gallery_by_job_id(job_id)

      socket
      |> assign(:order, Orders.get!(gallery, order_number) |> Repo.preload(:intent))
      |> assign(:gallery, gallery)
    end)
    |> assign_details()
    |> ok()
  end

  @impl true
  def handle_event("open-stripe", _, %{assigns: %{order: %{intent: nil}, current_user: current_user}} = socket), do:
    socket |> redirect(
      external:
        "https://dashboard.stripe.com/#{current_user.organization.stripe_account_id}/payments"
    )
    |> noreply()

  @impl true
  def handle_event("open-stripe", _, %{assigns: %{order: %{intent: intent}, current_user: current_user}} = socket), do:
    socket |> redirect(
      external:
        "https://dashboard.stripe.com/#{current_user.organization.stripe_account_id}/payments/#{intent.stripe_id}"
    )
    |> noreply()


  @impl true
  def handle_event("view_gallery", _, %{assigns: %{gallery: gallery}} = socket),
    do:
      socket
      |> push_redirect(to: Routes.gallery_photographer_index_path(socket, :index, gallery.id))
      |> noreply()

  defp assign_details(%{assigns: %{current_user: current_user, order: order}} = socket) do
    socket
    |> assign(
      organization_name: current_user.organization.name,
      shipping_address: order.delivery_info.address,
      shipping_name: order.delivery_info.name
    )
  end

  defdelegate total_cost(order), to: Cart
  defdelegate summary(assigns), to: PicselloWeb.GalleryLive.ClientShow.Cart.Summary
end
