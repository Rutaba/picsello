defmodule PicselloWeb.JobLive.Shoot do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Repo, Shoot, Job}

  @impl true
  def handle_params(%{"id" => job_id, "shoot_number" => shoot_number}, _url, socket) do
    socket
    |> assign(live_action: :jobs)
    |> assign_job(job_id)
    |> assign_shoot(shoot_number)
    |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="bg-blue-light-primary">
      <div class="px-6 py-2 lg:pb-6 center-container">
        <div class="text-xs text-blue-primary/50">
          <%= live_redirect to: Routes.job_path(@socket, :jobs) do %>
            <%= action_name(@live_action, :plural) %>
          <% end %>

          <.icon name="forth" class="inline-block w-2 h-2 stroke-current" />

          <%= live_redirect to: Routes.job_path(@socket, :jobs, @job.id) do %>
            <%= Job.name @job %>
          <% end %>

          <.icon name="forth" class="inline-block w-2 h-2 stroke-current" />

          <span class="font-semibold"><%= @shoot.name %></span>
        </div>

        <hr class="mt-2 border-white" />

        <div class="flex items-center justify-between">
          <div>
            <h2 class="mt-4 text-xs font-bold tracking-widest uppercase text-blue-primary/50"><%= Job.name @job %></h2>

            <h1 class="mb-4 text-3xl font-bold">
              <%= @shoot.name %>
            </h1>
          </div>
          <%= live_redirect to: Routes.job_path(@socket, :jobs, @job.id), class: "fixed sm:static bottom-4 left-4 right-4 text-center btn-primary" do %>
            Go back to <%= Job.name @job %>
          <% end %>
        </div>
      </div>
    </header>

    <div class="flex items-start justify-between p-4 m-4 border rounded-lg center-container">
      <div class="flex flex-col flex-wrap flex-1 sm:flex-row">
        <time datetime={DateTime.to_iso8601(@shoot.starts_at)} class="w-24 h-24 mb-2 mr-4 overflow-hidden text-center border rounded-lg border-blue-primary bg-blue-light-primary">
          <div class="py-1 text-sm font-semibold text-white uppercase bg-blue-primary">
            <%= strftime(@current_user.time_zone, @shoot.starts_at, "%B") %>
          </div>

          <div class="text-3xl font-bold text-blue-primary">
            <%= strftime(@current_user.time_zone, @shoot.starts_at, "%d") %>
          </div>

          <div class="text-sm text-blue-primary">
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
              <%= dyn_gettext @shoot.location %>

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

      <button title="edit shoot" phx-click="edit-shoot-details" class="flex items-center px-2 py-1 text-xs border btn-secondary border-blue-primary">
        <span class="text-blue-primary">
          <.icon name="pencil" class="inline-block w-3 h-3 mb-0.5 mr-1 fill-current" />
        </span>
        Edit
      </button>
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

  def handle_info({:update, %{shoot: shoot}}, socket) do
    shoot_index =
      Shoot.for_job(shoot.job_id)
      |> Repo.all()
      |> Enum.find_index(&(&1.id == shoot.id))

    socket
    |> push_patch(
      to: Routes.shoot_path(socket, :shoots, shoot.job_id, shoot_index + 1),
      replace: true
    )
    |> noreply()
  end

  defdelegate assign_job(socket, job_id), to: PicselloWeb.JobLive.Shared

  @doc """
    Load the shoot_number (1 based index) shoot of the job.
    raise Ecto.NoResultsError if not found.

    https://github.com/phoenixframework/phoenix_ecto/blob/v4.4.0/lib/phoenix_ecto/plug.ex#L4
  """
  defp assign_shoot(%{assigns: %{job: job}} = socket, shoot_number) do
    case job.id
         |> Shoot.for_job()
         |> Repo.all()
         |> Enum.at(String.to_integer(shoot_number) - 1) do
      nil -> raise Ecto.NoResultsError
      shoot -> assign(socket, shoot: shoot, shoot_number: shoot_number)
    end
  end
end
