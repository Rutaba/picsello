defmodule PicselloWeb.JobLive.Shared.NotesModal do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Job, Client, Repo}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> then(&assign(&1, changeset: build_changeset(&1)))
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <h1 class="flex justify-between mb-4 text-3xl font-bold">
        Edit Note

        <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
          <.icon name="close-x" class="w-3 h-3 stroke-current stroke-2 sm:stroke-1 sm:w-6 sm:h-6"/>
        </button>

      </h1>

      <.form :let={f} for={@changeset} phx-submit="save" phx-target={@myself}>
        <div class="mt-2">
          <div class="flex items-center justify-between mb-2">
            <%= label_for f, :notes, label: "Private Notes" %>

            <.icon_button color="red-sales-300" icon="trash" phx-hook="ClearInput" id="clear-notes" data-input-name={input_name(f,:notes)}>
              Clear
            </.icon_button>

          </div>

          <fieldset>
            <%= input f, :notes, type: :textarea, class: "w-full max-h-60", phx_hook: "AutoHeight", phx_update: "ignore" %>
          </fieldset>
        </div>

        <PicselloWeb.LiveModal.footer>
          <button class="btn-primary" title="save" type="submit" disabled={!@changeset.valid?} phx-disable-with="Saving...">
            Save
          </button>

          <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
            Cancel
          </button>
        </PicselloWeb.LiveModal.footer>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("save", %{"job" => params}, socket) do
    case socket |> build_changeset(params) |> Repo.update() do
      {:ok, job} ->
        send(socket.parent_pid, {:update, %{job: job}})

        socket |> close_modal() |> noreply()

      _ ->
        socket |> put_flash(:error, "could not save notes.") |> noreply()
    end
  end

  @impl true
  def handle_event("save", %{"client" => params}, socket) do
    case socket |> build_changeset(params) |> Repo.update() do
      {:ok, client} ->
        send(socket.parent_pid, {:update, %{client: client}})

        socket |> close_modal() |> noreply()

      _ ->
        socket |> put_flash(:error, "could not save notes.") |> noreply()
    end
  end

  def build_changeset(assigns, params \\ %{})

  def build_changeset(%{assigns: %{job: job}}, params) do
    Job.notes_changeset(job, params)
  end

  def build_changeset(%{assigns: %{client: client}}, params) do
    Client.notes_changeset(client, params)
  end

  def open(%{assigns: %{job: job}} = socket) do
    socket |> open_modal(__MODULE__, %{job: job})
  end

  def open(%{assigns: %{client: client}} = socket) do
    socket |> open_modal(__MODULE__, %{client: client})
  end
end
