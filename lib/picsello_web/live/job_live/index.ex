defmodule PicselloWeb.JobLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Job, Repo, Package, Payments}
  require Ecto.Query
  alias Ecto.Query
  import PicselloWeb.JobLive.Shared, only: [status_badge: 1]

  defmodule Pagination do
    @moduledoc false
    defstruct first_index: 1,
              last_index: 12,
              total_count: 0,
              limit: 12,
              after: nil,
              before: nil
  end

  @impl true
  def mount(_params, _session, %{assigns: %{live_action: action}} = socket) do
    socket
    |> assign_new(:pagination, fn -> %Pagination{} end)
    |> assign(:page_title, action |> Phoenix.Naming.humanize())
    |> assign_jobs()
    |> assign_stripe_status()
    |> ok()
  end

  @impl true
  def handle_event("create-lead", %{}, socket),
    do:
      socket
      |> open_modal(PicselloWeb.JobLive.NewComponent, Map.take(socket.assigns, [:current_user]))
      |> noreply()

  @impl true
  def handle_event("import-job", %{}, socket),
    do:
      socket
      |> open_modal(PicselloWeb.JobLive.ImportWizard, Map.take(socket.assigns, [:current_user]))
      |> noreply()

  @impl true
  def handle_event("page", %{"cursor" => cursor, "direction" => direction}, socket) do
    update_fn =
      case direction do
        "back" -> &%{&1 | after: nil, before: cursor, first_index: &1.first_index - &1.limit}
        "forth" -> &%{&1 | after: cursor, before: nil, first_index: &1.first_index + &1.limit}
      end

    socket |> update(:pagination, update_fn) |> assign_jobs() |> noreply()
  end

  @impl true
  def handle_event("page", %{"per-page" => per_page}, socket) do
    limit = String.to_integer(per_page)

    socket
    |> assign(:pagination, %Pagination{limit: limit, last_index: limit})
    |> assign_jobs()
    |> noreply()
  end

  @impl true
  def handle_event("page", %{}, socket), do: socket |> noreply()

  @impl true
  def handle_event("intro_js" = event, params, socket),
    do: PicselloWeb.LiveHelpers.handle_event(event, params, socket)

  @impl true
  def handle_info({:stripe_status, status}, socket) do
    socket |> assign(stripe_status: status) |> noreply()
  end

  defp assign_stripe_status(%{assigns: %{current_user: current_user}} = socket) do
    socket |> assign(stripe_status: Payments.status(current_user))
  end

  defp assign_jobs(
         %{assigns: %{current_user: current_user, live_action: action, pagination: pagination}} =
           socket
       ) do
    %{entries: jobs, metadata: metadata} =
      current_user
      |> Job.for_user()
      |> then(fn query ->
        case action do
          :leads -> query |> Job.leads()
          :jobs -> query |> Job.not_leads()
        end
      end)
      |> Query.preload([:client, :package, :shoots, :booking_proposals, :job_status])
      |> Query.order_by(desc: :updated_at)
      |> Repo.paginate(
        pagination
        |> Map.take([:before, :after, :limit])
        |> Map.to_list()
        |> Enum.concat(cursor_fields: [updated_at: :desc])
      )

    socket
    |> assign(
      jobs: jobs,
      pagination: %{
        pagination
        | total_count: metadata.total_count,
          after: metadata.after,
          before: metadata.before,
          last_index: pagination.first_index + Enum.count(jobs) - 1
      }
    )
  end

  def card_date(:jobs, "" <> time_zone, %Job{shoots: shoots}) do
    try do
      date =
        shoots
        |> Enum.map(& &1.starts_at)
        |> Enum.filter(&(DateTime.compare(&1, DateTime.utc_now()) == :gt))
        |> Enum.min(DateTime)

      strftime(time_zone, date, "%B %d, %Y @ %I:%M %p")
    rescue
      _e in Enum.EmptyError ->
        nil
    end
  end

  def card_date(:leads, _, _), do: nil

  def select(assigns) do
    ~H"""
    <div id="page-dropdown" class="flex items-center px-2 py-1 border rounded cursor-pointer border-blue-planning-300" phx-update="ignore" data-offset-y="10" phx-hook="Select">
      <div class="hidden border shadow popover-content">
        <%= for(option <- @options) do %>
          <label class={"p-2 pr-6 flex items-center cursor-pointer hover:bg-blue-planning-100 #{if @value == option, do: "bg-blue-planning-100", else: "bg-white"}"}>
            <input type="radio" class="hidden" name={@name} value={option} />
            <div class={"flex items-center justify-center w-5 h-5 mr-2 rounded-full #{if @value == option, do: "bg-blue-planning-300", else: "border"}"}>
              <.icon name="checkmark" class="w-3 h-3 stroke-current" />
            </div>
            <%= option %>
          </label>
        <% end %>
      </div>
      <span class="text-xs font-semibold"><%= @value %></span>
      <.icon name="down" class="w-3 h-3 ml-2 stroke-current stroke-2 open-icon text-blue-planning-300" />
      <.icon name="up" class="hidden w-3 h-3 ml-2 stroke-current stroke-2 close-icon text-blue-planning-300" />
    </div>
    """
  end
end
