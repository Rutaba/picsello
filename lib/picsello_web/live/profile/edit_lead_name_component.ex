defmodule PicselloWeb.Live.Profile.EditLeadNameComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <.close_x />
      <h1 class="text-3xl font-bold py-5">Edit Lead Name</h1>

      <form>
        <label class="input-label py-5" for="leadname">Client name:</label>
        <div>
        <input class="relative text-input" type="text" id="leadname" name="leadname" >
        </div>

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
  end

end
