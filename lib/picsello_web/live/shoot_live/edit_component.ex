defmodule PicselloWeb.ShootLive.EditComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{Shoot, Repo, Job}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_changeset(%{}, nil)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div class="flex flex-col modal">
        <h2 class="text-xl font-semibold"><%= Job.name @job %></h2>
        <h1 class="mt-2 title">Edit Shoot</h1>

        <.form let={f} for={@changeset}, phx-change="validate" phx-submit="save" phx-target={@myself}>
          <%= labeled_input f, :name, label: "Shoot name", placeholder: "Engagement Shoot" %>
          <%= labeled_input f, :starts_at, type: :datetime_local_input, label: "Shoot date", min: Date.utc_today(), time_zone: @current_user.time_zone, wrapper_class: "mt-4" %>
          <%= labeled_select f, :duration_minutes, for(duration <- Shoot.durations(), do: {dyn_gettext("duration-#{duration}"), duration }), label: "Shoot duration", prompt: "Select below", wrapper_class: "mt-4" %>
          <div class="mt-4 input-label">Shoot location</div>
          <%= for location <- Shoot.locations() do %>
            <label class="flex items-center mb-2">
              <%= radio_button f, :location, location, class: "mr-2 radio" %>
              <%= dyn_gettext location %>
            </label>
          <% end %>
          <%= labeled_input f, :notes, type: :textarea, label: "Shoot notes", placeholder: "type notes here" %>

          <%= live_component PicselloWeb.LiveModal.FooterComponent, disabled: !@changeset.valid? %>
        </.form>
      </div>
    """
  end

  @impl true
  def handle_event("validate", %{"shoot" => params}, socket) do
    socket |> assign_changeset(params, :validate) |> noreply()
  end

  @impl true
  def handle_event(
        "save",
        %{"shoot" => params},
        socket
      ) do
    case socket |> build_changeset(params) |> upsert do
      {:ok, shoot} ->
        send(
          self(),
          {:update, socket.assigns |> Map.take([:shoot_number]) |> Map.put(:shoot, shoot)}
        )

        socket |> assign(shoot: shoot) |> close_modal() |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  defp build_changeset(
         %{assigns: %{current_user: %{time_zone: time_zone}}} = socket,
         %{"starts_at" => "" <> starts_at} = params
       ) do
    socket
    |> build_changeset(
      params
      |> Map.put(
        "starts_at",
        parse_in_zone(starts_at, time_zone)
      )
    )
  end

  defp build_changeset(%{assigns: %{shoot: shoot}}, params) when shoot != nil do
    shoot |> Shoot.update_changeset(params)
  end

  defp build_changeset(%{assigns: %{job: %{id: job_id}}}, params) do
    params
    |> Map.put("job_id", job_id)
    |> Shoot.create_changeset()
  end

  defp upsert(changeset) do
    case changeset |> Ecto.Changeset.get_field(:id) do
      nil -> changeset |> Repo.insert()
      _ -> changeset |> Repo.update()
    end
  end

  defp assign_changeset(
         socket,
         params,
         action
       ) do
    changeset = build_changeset(socket, params) |> Map.put(:action, action)
    assign(socket, changeset: changeset)
  end

  defp parse_in_zone("" <> str, zone) do
    with {:ok, naive_datetime} <- NaiveDateTime.from_iso8601(str <> ":00"),
         {:ok, datetime} <- DateTime.from_naive(naive_datetime, zone) do
      datetime
    end
  end
end
