defmodule PicselloWeb.JobLive.Transaction.Index do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Cart, Job, Repo, Galleries}
  require Ecto.Query
  alias Ecto.Query
  import PicselloWeb.JobLive.Shared, only: [assign_job: 2]

  @impl true
  def mount(%{"id" => job_id}, _session, %{assigns: %{live_action: action}} = socket) do
    gallery = Galleries.get_gallery_by_job_id(job_id) |> Repo.preload([:job, orders: [:intent, :products, :digitals]])
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

  defp order_date(_, %{placed_at: nil}), do: nil
  defp order_date(time_zone, %{placed_at: placed_at}), do: strftime(time_zone, placed_at, "%m/%d/%Y")
  defp order_date(time_zone, nil), do: nil

  defdelegate total_cost(order), to: Cart
end
