defmodule PicselloWeb.Shared.EditNameComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Repo, Job, BookingEvent, BookingEvents}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_changeset()
    |> ok()
  end

  @impl true
  def handle_event("validate", %{"job" => %{"name" => name}}, socket) do
    socket
    |> assign_changeset(%{job_name: name})
    |> noreply()
  end

  @impl true
  def handle_event("validate", %{"booking_event" => params}, socket) do
    socket
    |> assign_changeset(params)
    |> noreply()
  end

  @impl true
  def handle_event("click", _, socket) do
    socket
    |> assign(:edit_name, true)
    |> noreply()
  end

  @impl true
  def handle_event("close", _, socket) do
    socket
    |> assign(:edit_name, false)
    |> noreply()
  end

  @impl true
  def handle_event("save", %{"job" => _params}, %{assigns: %{changeset: changeset}} = socket) do
    case Repo.update(changeset) do
      {:ok, job} ->
        send(socket.root_pid, {:update, %{job: job}})
        socket

      {:error, changeset} ->
        socket |> assign(changeset: changeset)
    end
    |> noreply()
  end

  @impl true
  def handle_event(
        "save",
        %{"booking_event" => _params},
        %{assigns: %{changeset: changeset}} = socket
      ) do
    case BookingEvents.upsert_booking_event(changeset) do
      {:ok, booking_event} ->
        send(socket.root_pid, {:update, %{booking_event: booking_event}})
        socket

      {:error, changeset} ->
        socket |> assign(changeset: changeset)
    end
    |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div class="flex items-center mt-4 md:justify-start">
        <div class="flex items-center">
          <.live_link to={@back_path} class="rounded-full bg-base-200 flex items-center justify-center p-2.5 mt-2 mr-4">
            <.icon name="back" class="w-4 h-4 stroke-2"/>
          </.live_link>
          <.form :let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>
            <div class={classes("flex items-center gap-4", %{"hidden" => @edit_name})}>
              <p class="w-auto text-3xl font-bold text-base-300"><%= if Map.has_key?(@data, :name), do: @data.name, else: Job.name(@data) %> </p>
              <.icon_button disabled={false} phx_click="click" phx-target={@myself} class="bg-gray-200 pt-2 pb-2 shadow-lg" color="blue-planning-300" icon="pencil" />
            </div>
            <div class={classes("flex items-center", %{"hidden" => !@edit_name})}>
              <%= input f, :name, value: (if Map.has_key?(@data, :name), do: @data.name, else: Job.name(@data)), class: "w-full text-input" %>
              <%= submit "Save", disabled: !@changeset.valid?, class: "ml-4 mb-2 btn-save-side-nav" %>
              <button class="flex ml-2 mb-2 px-4 py-2 mt-4 border rounded-lg shadow-lg hover:opacity-75 border-black" title="cancel" type="button" phx-click="close" phx-target={@myself}>Cancel</button>
            </div>
          </.form>
        </div>
      </div>
    """
  end

  def edit_name_input(assigns) do
    ~H"""
      <.live_component module={__MODULE__} id={assigns[:id] || "edit_name_input"} {assigns} />
    """
  end

  defp assign_changeset(socket, params \\ %{})

  defp assign_changeset(%{assigns: %{data: %{job_name: _} = data}} = socket, params) do
    socket
    |> assign(:changeset, Job.edit_job_changeset(data, params))
  end

  defp assign_changeset(%{assigns: %{data: %{thumbnail_url: _} = data}} = socket, params) do
    socket
    |> assign(:changeset, BookingEvent.create_changeset(data, params))
  end
end
