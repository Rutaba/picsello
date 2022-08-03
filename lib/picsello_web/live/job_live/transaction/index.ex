defmodule PicselloWeb.JobLive.Transaction.Index do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Cart, Job, Repo, Galleries}
  require Ecto.Query
  import PicselloWeb.JobLive.Shared, only: [assign_job: 2]

  @impl true
  def mount(%{"id" => job_id}, _session, %{assigns: %{live_action: action}} = socket) do
    socket
    |> assign(:page_title, action |> Phoenix.Naming.humanize())
    |> assign_job(job_id)
    |> then(fn socket ->
      gallery =
        Galleries.get_gallery_by_job_id(job_id)
        |> Repo.preload(orders: [:intent, :products, :digitals])

      socket
      |> assign(:gallery, gallery)
    end)
    |> ok()
  end

  @impl true
  def handle_event(
        "order-detail",
        %{"order_number" => order_number},
        %{assigns: %{job: job}} = socket
      ) do
    socket
    |> push_redirect(to: Routes.order_detail_path(socket, :transactions, job.id, order_number))
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

  defp order_status(%{intent: %{status: status}}) when is_binary(status),
    do: String.capitalize(status)

  defp order_status(_), do: "Processed"

  defdelegate total_cost(order), to: Cart
end
