defmodule PicselloWeb.ShootLive.EditComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{Shoot, Repo}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_new(:address_field, fn ->
      match?(%{shoot: %{address: address}} when not is_nil(address), assigns)
    end)
    |> assign_changeset(%{}, nil)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div class="flex flex-col modal">
        <div class="flex items-start justify-between flex-shrink-0">
          <h1 class="mb-4 text-3xl font-bold">Edit Shoot Details</h1>

          <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
            <.icon name="close-x" class="w-3 h-3 stroke-current stroke-2 sm:stroke-1 sm:w-6 sm:h-6"/>
          </button>
        </div>

        <.form let={f} for={@changeset}, phx-change="validate" phx-submit="save" phx-target={@myself}>

          <div class="px-1.5 grid grid-cols-1 sm:grid-cols-6 gap-5">
            <%= labeled_input f, :name, label: "Shoot Title", placeholder: "e.g. #{@job.type |> String.capitalize()} Session, etc.", wrapper_class: "sm:col-span-3" %>
            <%= labeled_input f, :starts_at, type: :datetime_local_input, label: "Shoot Date", min: Date.utc_today(), time_zone: @current_user.time_zone, wrapper_class: "sm:col-span-3", class: "w-full" %>
            <%= labeled_select f, :duration_minutes, for(duration <- Shoot.durations(), do: {dyn_gettext("duration-#{duration}"), duration }),
                  label: "Shoot Duration",
                  prompt: "Select below",
                  wrapper_class: classes("",%{"sm:col-span-3" => !@address_field, "sm:col-span-2" => @address_field})
            %>

            <div class={classes("flex flex-col", %{"sm:col-span-3" => !@address_field, "sm:col-span-2" => @address_field} |> Map.merge(select_invalid_classes(f, :location)))}>
              <div class="flex items-center justify-between">
                <%= label_for f, :location, label: "Shoot Location" %>

                <%= unless @address_field do %>
                  <a class="text-xs link" href="#" phx-target={@myself} phx-click="address" phx-value-action="add-field">Add an address</a>
                <% end %>
              </div>

            <%= select_field f, :location, for(location <- Shoot.locations(), do: {location |> Atom.to_string() |> dyn_gettext(), location }), prompt: "Select below" %>
            </div>

            <%= if @address_field do %>
              <div class="flex flex-col sm:col-span-2">
                <div class="flex items-center justify-between">
                  <%= label_for f, :address, label: "Shoot Address" %>

                  <a class="text-xs link" href="#" phx-target={@myself} phx-click="address" phx-value-action="remove">Remove address</a>
                </div>

                <%= input f, :address, phx_hook: "PlacesAutocomplete", autocomplete: "off" %>
                <div class="relative autocomplete-wrapper" phx-update="ignore"></div>
              </div>
            <% end %>

            <%= labeled_input f, :notes, type: :textarea, label: "Shoot Notes", placeholder: "e.g. Anything you'd like to remember", wrapper_class: "sm:col-span-6" %>
          </div>

          <PicselloWeb.LiveModal.footer disabled={!@changeset.valid?} />
        </.form>
      </div>
    """
  end

  @impl true
  def handle_event("address", %{"action" => "add-field"}, socket) do
    socket |> assign(address_field: true) |> noreply()
  end

  @impl true
  def handle_event(
        "address",
        %{"action" => "remove"},
        %{assigns: %{changeset: changeset}} = socket
      ) do
    socket
    |> assign(
      address_field: false,
      changeset: Ecto.Changeset.put_change(changeset, :address, nil)
    )
    |> noreply()
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
    case socket |> build_changeset(params |> Enum.into(%{"address" => nil})) |> upsert do
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
