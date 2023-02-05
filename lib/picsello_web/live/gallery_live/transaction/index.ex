defmodule PicselloWeb.GalleryLive.Transaction.Index do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Cart, Job, Repo, Galleries}
  require Ecto.Query

  import PicselloWeb.JobLive.Shared, only: [assign_job: 2]
  import PicselloWeb.GalleryLive.Shared, only: [order_status: 1, tag_for_gallery_type: 1]

  @impl true
  def mount(%{"id" => gallery_id}, _session, %{assigns: %{live_action: action}} = socket) do
    socket
    |> assign(:page_title, action |> Phoenix.Naming.humanize())
    |> then(fn socket ->
      gallery =
        gallery_id
        |> Galleries.get_gallery!()
        |> Repo.preload(orders: [:intent, :products, :digitals])

      socket
      |> assign_job(gallery.job_id)
      |> assign(:gallery, gallery)
    end)
    |> ok()
  end

  @impl true
  def handle_event(
        "order-detail",
        %{"order_number" => order_number},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    socket
    |> push_redirect(
      to:
        Routes.order_detail_path(socket, :transactions, gallery.id, order_number, %{
          "request_from" => "transactions"
        })
    )
    |> noreply()
  end

  @impl true
  def handle_event("open-stripe", _, %{assigns: %{current_user: current_user}} = socket) do
    socket
    |> redirect(
      external:
        "https://dashboard.stripe.com/#{current_user.organization.stripe_account_id}/payments"
    )
    |> noreply()
  end

  defp order_date(time_zone, order) do
    case order do
      %{placed_at: placed_at} when placed_at != nil -> strftime(time_zone, placed_at, "%m/%d/%Y")
      _ -> nil
    end
  end

  defdelegate total_cost(order), to: Cart
end
