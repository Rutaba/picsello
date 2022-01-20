defmodule PicselloWeb.Live.Marketing.CampaignDetailsComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Marketing

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_new(:campaign, fn ->
      Marketing.get_recent_campaign(assigns.campaign_id, assigns.current_user.organization_id)
    end)
    |> then(fn socket ->
      socket
      |> assign_new(:template_preview, fn ->
        Process.send_after(
          self(),
          {:load_template_preview, __MODULE__, socket.assigns.campaign.body_html},
          50
        )

        :loading
      end)
    end)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <div class="flex items-start justify-between flex-shrink-0">
        <h1 class="text-3xl font-bold"><%= @campaign.subject %></h1>

        <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
          <.icon name="close-x" class="w-3 h-3 stroke-current stroke-2 sm:stroke-1 sm:w-6 sm:h-6"/>
        </button>
      </div>

      <div class="mt-3 p-3 rounded-lg border w-full">
        <dl>
          <dt class="inline text-blue-planning-300">Recipient list:</dt>
          <dd class="inline"><%= ngettext "1 contact", "%{count} contacts", @campaign.clients_count %></dd>
        </dl>
        <dl>
          <dt class="inline text-blue-planning-300">Date:</dt>
          <dd class="inline"><%= strftime(@current_user.time_zone, @campaign.inserted_at, "%B %d, %Y") %></dd>
        </dl>
      </div>
      <%= case @template_preview do %>
        <% nil -> %>
        <% :loading -> %>
          <div class="flex items-center justify-center w-full mt-10 text-xs">
            <div class="w-3 h-3 mr-2 rounded-full opacity-75 bg-blue-planning-300 animate-ping"></div>
            Loading...
          </div>
        <% content -> %>
          <div class="rounded-lg bg-base-200 flex justify-center mt-4 p-2">
            <iframe srcdoc={content} class="w-[30rem]" scrolling="no" phx-hook="IFrameAutoHeight" id="template-preview">
            </iframe>
          </div>
      <% end %>

      <PicselloWeb.LiveModal.footer>
        <button id="close" class="btn-secondary" title="close" type="button" phx-click="modal" phx-value-action="close">
          Close
        </button>
      </PicselloWeb.LiveModal.footer>
    </div>
    """
  end

  def open(%{assigns: assigns} = socket, campaign_id),
    do:
      open_modal(
        socket,
        __MODULE__,
        %{
          assigns: assigns |> Map.take([:current_user]) |> Map.put(:campaign_id, campaign_id)
        }
      )
end
