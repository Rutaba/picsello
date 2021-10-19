defmodule PicselloWeb.JobLive.Shared.NotesModal do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Job, Repo}

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
    <div class="max-w-2xl modal">
      <h1 class="flex justify-between mb-4 text-3xl font-bold">
        Edit Note

        <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
          <.icon name="close-x" class="w-3 h-3 stroke-current stroke-2 sm:stroke-1 sm:w-6 sm:h-6"/>
        </button>

      </h1>

      <.form let={f} for={@changeset}, phx-submit="save" phx-target={@myself}>
        <div class="mt-2">
          <div class="flex items-center justify-between mb-2">
            <%= label_for f, :notes, label: "Private Notes" %>

            <%= if @edit_mode do %>
              <.icon_button color="red-sales-300" icon="trash" phx-hook="ClearInput" id="clear-notes" data-input-name={input_name(f,:notes)}>
                Clear
              </.icon_button>
            <% else %>
              <.icon_button color="blue-planning-300" icon="pencil" phx-click="enable-edit" phx-target={@myself}>
                Edit
              </.icon_button>
            <% end %>

          </div>

          <fieldset disabled={!@edit_mode}>
            <%= input f, :notes, type: :textarea, class: "w-full", phx_hook: "AutoHeight", phx_update: "ignore" %>
          </fieldset>
        </div>

        <PicselloWeb.LiveModal.footer>
          <div class="flex flex-col gap-2 sm:flex-row-reverse">
            <%= if @edit_mode do %>
              <button class="px-8 mb-2 sm:mb-0 btn-primary" title="save" type="submit" disabled={!@changeset.valid?} phx-disable-with="Saving...">
                Save
              </button>

              <button class="px-8 btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
                Cancel
              </button>
            <% else %>
              <button class="px-8 btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
                Close
              </button>
            <% end %>
          </div>
        </PicselloWeb.LiveModal.footer>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("enable-edit", %{}, socket),
    do: socket |> assign(:edit_mode, true) |> noreply()

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

  def build_changeset(%{assigns: %{job: job}}, params \\ %{}) do
    Job.notes_changeset(job, params)
  end

  def open(%{assigns: %{job: job}} = socket) do
    socket |> open_modal(__MODULE__, %{edit_mode: !job.notes, job: job})
  end
end
