defmodule PicselloWeb.JobLive.Transaction.Index do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Cart, Job, Repo, Galleries}
  require Ecto.Query
  import PicselloWeb.JobLive.Shared, only: [redirect_to_stripe: 1]

  @impl true
  def mount(%{"id" => job_id}, _session, %{assigns: %{live_action: action}} = socket) do
    gallery = Galleries.get_gallery_by_job_id(job_id) |> Repo.preload([job: [:client], orders: [:intent, :products, :digitals]])
    IO.inspect(gallery)
    socket
    |> assign(:page_title, action |> Phoenix.Naming.humanize())
    |> assign(:job_id, job_id)
    |> assign(:gallery, gallery)
    |> ok()
  end

  @impl true
  def handle_event("order-detail", %{"order_number" => order_number}, %{assigns: %{gallery: %{job: job}}} = socket) do
    socket
    |> push_redirect(to: Routes.order_detail_path(socket, :transactions, job.id, order_number))
    |> noreply()
  end

  @impl true
  def handle_event("open-stripe", _, socket), do: socket |> redirect_to_stripe()

  defp order_date(time_zone, order) do
    case order do
      %{placed_at: placed_at} when placed_at != nil -> strftime(time_zone, placed_at, "%m/%d/%Y")
      _ -> nil
    end
  end

  defp order_status(%{intent: %{status: status}}), do: status
  defp order_status(_), do: "processed"

  defdelegate total_cost(order), to: Cart
end
