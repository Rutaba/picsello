defmodule PicselloWeb.Live.Profile.EditNameSharedComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  alias Picsello.{Repo, Job}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(:changeset, Job.edit_job_changeset(assigns.job, %{}))
    |> ok()
  end

  @impl true
  def handle_event("save", %{"job" => params}, socket) do
    changeset = socket |> build_changeset(params)
    case Repo.update(changeset) do
      {:ok, job} ->
        send(socket.parent_pid, {:update, %{job: job}})
        socket
        |> close_modal()
      {:error, changeset} ->
        socket |> assign(changeset: changeset)
    end
    |> noreply()
  end

  def handle_event("validate", %{"job" => params}, socket) do
    socket
    |> assign(:changeset, build_changeset(socket, params))
    |> noreply()
  end

  defp build_changeset(%{assigns: %{job: job}} = _socket, params) do
    Job.edit_job_changeset(job, params)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <.close_x />
      <%= if assigns.job.job_status.is_lead do %>
        <h1 class="text-3xl font-bold py-5"> Edit Lead Name</h1>
      <% else %>
        <h1 class="text-3xl font-bold py-5"> Edit Job Name</h1>
      <% end %>
      <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>
        <div class="py-5">
          <%= labeled_input f, :job_name, label: "Name:", class: "h-12", phx_debounce: "500" %>
        </div>

        <.footer>
          <button class="btn-primary px-11" title="save" type="submit" disabled={!@changeset.valid?} phx-disable-with="Sending...">
            Save
          </button>
          <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
            Cancel
          </button>
        </.footer>
      </.form>
    </div>
    """
  end
end
