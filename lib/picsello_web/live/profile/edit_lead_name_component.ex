defmodule PicselloWeb.Live.Profile.EditLeadNameComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  alias Picsello.{Job, Jobs, Repo}

@impl true
def update(assigns, socket) do
  socket
  |> assign(assigns)
  |> ok()
end

  @impl true
  def render(assigns) do
    IO.inspect(assigns)
    ~H"""
    <div class="modal">
      <.close_x />
      <h1 class="text-3xl font-bold py-5">Edit Lead Name</h1>
      <form>
        <label class="input-label py-5" for="leadname">Client name:</label>
        <input class="relative text-input" type="text" id="leadname" name="leadname" value={assigns.job.client.name}>

        <.footer>
          <button class="btn-primary px-11" title="save" type="submit" phx-disable-with="Sending...">
            Save
          </button>
          <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
            Cancel
          </button>
        </.footer>
      </form>
    </div>
    """
    # <%= {@job}  %>
  end
end
