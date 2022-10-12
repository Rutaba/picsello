defmodule PicselloWeb.Live.Profile.EditLeadNameComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  alias Picsello.{Job, Repo}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> ok()
  end

  @impl true
  def handle_event("save", %{"value" => ""}, socket) do
    #socket
    #|> assign(client_name: socket.assign.job.client.name)
    IO.inspect(socket.params)
    case socket |> build_changeset(socket.params) |> Repo.update() do
      {:ok, job} ->
        send(socket.parent_pid, {:update, %{job: job}})

        socket |> close_modal() |> noreply()

      _ ->
        socket |> put_flash(:error, "Could not save new name.") |> noreply()
    end
  end

  #@impl


  def handle_event("validate", %{"leadname" => params}, socket) do
    socket |> assign_changeset(%{name: params}) |> noreply()
  end

  defp build_changeset(socket, params) do

    client = %{socket.assigns.job.client | name: params}
    job = %{socket.assigns.job | client: client}
    IO.inspect(job)
    %{job: job}
    |> Job.create_changeset()

  end

  defp assign_changeset(socket, params) do

     changeset =
       socket
       |> build_changeset(params)
       |> Map.put(:action, :validate)

      IO.inspect(changeset)
     assign(socket, changeset: changeset)

   end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <.close_x />
      <h1 class="text-3xl font-bold py-5">Edit Lead Name</h1>
      <form phx-target={@myself} phx-change="validate">
        <label class="input-label py-5" for="leadname">Client name:</label>
        <input class="relative text-input" type="text" id="leadname" name="leadname" value={@job.client.name} >

        <.footer>
          <button class="btn-primary px-11" title="save" type="button" phx-click="save">
            Save
          </button>
          <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
            Cancel
          </button>
        </.footer>
      </form>
    </div>
    """
  end
end
