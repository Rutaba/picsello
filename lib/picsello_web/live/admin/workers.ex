defmodule PicselloWeb.Live.Admin.Workers do
  @moduledoc "kick off background jobs"
  use PicselloWeb, live_view: [layout: false]
  import Ecto.Query, only: [from: 2]

  @workers [
    Picsello.Workers.SyncEmailPresets,
    Picsello.Workers.SyncTiers,
    Picsello.Workers.SyncWHCCCatalog,
    Picsello.Workers.SyncSubscriptionPricing
  ]

  @queue "user_initiated"

  @impl true
  def mount(_params, _session, socket) do
    poll()

    socket
    |> assign(workers: for(worker <- @workers, do: {name(worker), worker}))
    |> assign_jobs()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="p-8 bg-gray-100">
      <h1 class="text-4xl font-bold">Execute Workers</h1>
    </header>
    <div class="p-8">
      <ul class="my-4 flex grid gap-10 grid-cols-1 sm:grid-cols-4">
        <%= for {name, _} <- @workers do %>
          <li><button phx-click="start" phx-value-name={name} class="border flex items-center justify-center rounded-lg p-8 font-bold text-blue-planning-300 w-full"><%= name %></button></li>
        <% end %>
      </ul>

      <%= unless Enum.empty?(@jobs) do %>
        <h2 class="text-lg">Currently Working</h2>

        <div class="mt-4 grid gap-2 items-center">
        <div class="col-start-1 font-bold">Worker</div>
        <div class="col-start-2 font-bold">State</div>
        <div class="col-start-3 font-bold">Attempted</div>
        <div class="col-start-4 font-bold">Completed</div>

        <%= for %{completed_at: completed_at, attempted_at: attempted_at, worker: worker, state: state} <- @jobs do %>
          <div class="contents">
            <div class="col-start-1"><%= name(worker) %></div>
            <div class="col-start-2"><%= state %></div>
            <div class="col-start-3"><%= attempted_at %></div>
            <div class="col-start-4"><%= completed_at %></div>
          </div>
        <% end %>

        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("start", %{"name" => name}, %{assigns: %{workers: workers}} = socket) do
    worker = workers |> Map.new() |> Map.get(name)

    case Oban.insert(worker.new(%{}, queue: to_string(@queue), unique: [period: 5])) do
      {:ok, _job} -> socket |> assign_jobs() |> noreply()
    end
  end

  @impl true
  def handle_info(:poll, socket) do
    poll()
    socket |> assign_jobs() |> noreply()
  end

  defp name(mod),
    do: mod |> Phoenix.Naming.underscore() |> Path.basename() |> Phoenix.Naming.humanize()

  defp poll() do
    Process.send_after(self(), :poll, 1000)
  end

  defp assign_jobs(socket) do
    minute_ago = DateTime.utc_now() |> DateTime.add(-60) |> DateTime.truncate(:second)

    jobs =
      from(job in Oban.Job,
        where:
          job.queue == ^@queue and (is_nil(job.completed_at) or job.completed_at > ^minute_ago),
        order_by: [desc: job.id]
      )
      |> Picsello.Repo.all()

    assign(socket, jobs: jobs)
  end
end
