defmodule PicselloWeb.JobLive.Shoot do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Repo, Shoot, Job}

  @impl true
  def handle_params(%{"id" => job_id, "shoot_number" => shoot_number}, _url, socket) do
    socket
    |> assign_job(job_id)
    |> assign_shoot(shoot_number)
    |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="pt-10 pb-8">
      <div class="px-6 py-2 lg:pb-6 center-container">
        <.crumbs>
          <:crumb to={Routes.job_path(@socket, @live_action)}><%= action_name(@live_action, :plural) %></:crumb>
          <:crumb to={Routes.job_path(@socket, @live_action, @job.id)}><%= Job.name @job %></:crumb>
          <:crumb><%= @shoot.name %></:crumb>
        </.crumbs>

        <hr class="mt-2 border-white" />

        <div class="flex items-center justify-between">
          <div>
            <h2 class="mt-4 text-xs font-bold tracking-widest uppercase text-blue-planning-200"><%= Job.name @job %></h2>

            <h1 class="mb-4 text-3xl font-bold">
              <%= @shoot.name %>
            </h1>
          </div>
          <%= live_redirect to: Routes.job_path(@socket, @live_action, @job.id), class: "fixed sm:static bottom-4 left-4 right-4 text-center btn-primary" do %>
            Go back to <%= Job.name @job %>
          <% end %>
        </div>
      </div>
    </header>

    <div class="flex items-start justify-between p-4 m-4 border rounded-lg center-container">
      <div class="flex flex-col flex-1 sm:flex-wrap sm:flex-row">
        <time datetime={DateTime.to_iso8601(@shoot.starts_at)} class="w-24 h-24 mb-2 mr-4 overflow-hidden text-center border rounded-lg border-blue-planning-300 bg-blue-planning-100">
          <div class="py-1 text-sm font-semibold text-white uppercase bg-blue-planning-300">
            <%= strftime(@current_user.time_zone, @shoot.starts_at, "%B") %>
          </div>

          <div class="text-3xl font-bold text-blue-planning-300">
            <%= strftime(@current_user.time_zone, @shoot.starts_at, "%d") %>
          </div>

          <div class="text-sm text-blue-planning-300">
            <%= strftime(@current_user.time_zone, @shoot.starts_at, "%I:%M %p") %>
          </div>
        </time>

        <div class="flex-grow grid grid-cols-1 sm:grid-cols-3 gap-4">
          <dl>
            <dt class="text-sm font-bold">Shoot Duration</dt>
            <dd><%= dyn_gettext "duration-#{@shoot.duration_minutes}" %></dd>
          </dl>

          <dl class="sm:col-span-2">
            <dt class="text-sm font-bold">Shoot Location</dt>
            <dd>
              <%= @shoot.location |> Atom.to_string() |> dyn_gettext() %>

              <%= if @shoot.address do %>
                <span class="ml-2"><%= @shoot.address %></span>
              <% end %>
            </dd>
          </dl>

          <dl class="sm:col-span-3">
            <dt class="text-sm font-bold">Shoot Notes</dt>
            <%= if @shoot.notes do %>
              <dd><%= @shoot.notes %></dd>
            <% else %>
              <dd class="text-gray-400">Click edit to add notes</dd>
            <% end %>
          </dl>
        </div>
      </div>

      <.icon_button title="edit shoot" phx-click="edit-shoot-details" color="blue-planning-300" icon="pencil">
        Edit
      </.icon_button>
    </div>
    """
  end

  @impl true
  def handle_event("edit-shoot-details", %{}, socket) do
    socket
    |> open_modal(
      PicselloWeb.ShootLive.EditComponent,
      socket.assigns
      |> Map.take([:current_user, :job, :shoot])
    )
    |> noreply()
  end

  def handle_info(
        {:update, %{shoot: shoot}},
        %{assigns: %{live_action: live_action}} = socket
      ) do
    shoots =
      Shoot.for_job(shoot.job_id)
      |> Repo.all()

    shoot_index =
      shoots
      |> Enum.find_index(&(&1.id == shoot.id))

    socket
    |> push_patch(
      to: Routes.shoot_path(socket, live_action, shoot.job_id, shoot_index + 1),
      replace: true
    )
    |> noreply()
  end

  defdelegate assign_job(socket, job_id), to: PicselloWeb.JobLive.Shared

  defp assign_shoot(%{assigns: %{job: job}} = socket, shoot_number) do
    queryable = Shoot.for_job(job.id)

    shoot_index = String.to_integer(shoot_number) - 1

    shoot =
      case queryable |> Repo.all() do
        # trigger a 404 response
        [] -> raise Ecto.NoResultsError, queryable: queryable
        shoots when length(shoots) > shoot_index -> Enum.at(shoots, shoot_index)
        shoots -> shoots |> Enum.reverse() |> hd
      end

    assign(socket, shoot: shoot, shoot_number: shoot_number)
  end
end
