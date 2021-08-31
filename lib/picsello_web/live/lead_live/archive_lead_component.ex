defmodule PicselloWeb.LeadLive.ArchiveLeadComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{Job}

  @impl true
  def render(assigns) do
    ~L"""
    <div class="max-w-md modal">
      <%= icon_tag(@socket, "warning", class: "h-16") %>

      <h1 class="text-3xl font-semibold">Are you sure you want to archive this lead?</h1>

      <button class="w-full mt-6 btn-warning" title="Archive lead" type="button" phx-click="archive" phx-disable-with="archiving&hellip;" phx-target="<%= @myself %>">
        Yes, archive the lead
      </button>

      <button class="w-full mt-6 btn-secondary" type="button" phx-click="modal" phx-value-action="close">
        No! Get me out of here
      </button>
    </div>
    """
  end

  def open_modal(%{assigns: assigns} = socket) do
    socket
    |> open_modal(__MODULE__, assigns |> Map.take([:live_action, :job]))
  end

  def handle_event(
        "archive",
        %{},
        %{assigns: %{job: %{id: job_id}, live_action: live_action}} = socket
      ) do
    send(socket.parent_pid, :archive)

    socket
    |> noreply()
  end
end
