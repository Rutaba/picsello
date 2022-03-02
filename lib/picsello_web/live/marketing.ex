defmodule PicselloWeb.Live.Marketing do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Marketing, Profiles}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Marketing")
    |> assign_organization()
    |> assign_campaigns()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="bg-purple-marketing-100">
      <h1 class="px-6 py-8 text-3xl font-semibold center-container">Marketing</h1>
    </header>
    <div class="px-6 center-container" {intro(@current_user, "intro_marketing")}>
      <div class="mx-0 mt-8 pb-32 sm:pb-0 grid grid-cols-1 lg:grid-cols-2 gap-x-9 gap-y-6">
        <.card title="Promotional Emails" class={classes("relative intro-promotional", %{"sm:col-span-2" => Enum.any?(@campaigns)})}>
          <%= if Enum.empty?(@campaigns) do %>
            <p class="mb-8">
              Reach out to your contacts and future clients with our easy-to-use tools.
            </p>
          <% end %>
          <div class={classes("flex flex-col gap-3 sm:flex-row justify-end mb-6 sm:mb-0", %{"sm:-mt-8" => Enum.any?(@campaigns)})}>
            <button type="button" phx-click="new-campaign" class="w-full sm:w-auto text-center btn-primary">Create an email</button>
          </div>
          <%= unless Enum.empty?(@campaigns) do %>
            <h2 class="mb-4 text-sm font-bold tracking-widest text-gray-400 uppercase">Most Recent</h2>

            <ul class="text-left grid gap-5 lg:grid-cols-2 grid-cols-1">
              <%= for campaign <- @campaigns do %>
                <.campaign_item id={campaign.id} subject={campaign.subject} date={strftime(@current_user.time_zone, campaign.inserted_at, "%B %d, %Y")} clients_count={campaign.clients_count} />
              <% end %>
            </ul>
          <% end %>
        </.card>
      </div>
    </div>
    """
  end

  defp card(assigns) do
    assigns = assigns |> Enum.into(%{class: ""})

    ~H"""
    <div class={"flex overflow-hidden border rounded-lg #{@class}"}>
      <div class="w-4 border-r bg-purple-marketing-300" />

      <div class="flex flex-col w-full p-4">
        <h1 class="text-xl font-bold mb-2"><%= @title %></h1>

        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  defp campaign_item(assigns) do
    ~H"""
    <li {testid("campaign-item")} phx-click="open-campaign" phx-value-campaign-id={@id} class="border rounded-lg p-4 hover:bg-purple-marketing-100 hover:border-purple-marketing-300 cursor-pointer">
      <.badge color={:green}>Sent</.badge>
      <div class="text-xl font-semibold"><%= @subject %></div>
      <div class="text-gray-400 mt-1">Sent on <%= @date %> to <%= ngettext "1 client", "%{count} clients", @clients_count %></div>
    </li>
    """
  end

  @impl true
  def handle_event("new-campaign", %{}, socket) do
    socket |> PicselloWeb.Live.Marketing.NewCampaignComponent.open() |> noreply()
  end

  @impl true
  def handle_event("open-campaign", %{"campaign-id" => campaign_id}, socket) do
    socket |> PicselloWeb.Live.Marketing.CampaignDetailsComponent.open(campaign_id) |> noreply()
  end

  @impl true
  def handle_event("intro_js" = event, params, socket),
    do: PicselloWeb.LiveHelpers.handle_event(event, params, socket)

  @impl true
  def handle_info({:update, _campaign}, socket) do
    socket
    |> assign_campaigns()
    |> put_flash(:success, "Promotional Email sent")
    |> noreply()
  end

  @impl true
  def handle_info(
        {:load_template_preview, component, body_html},
        %{assigns: %{current_user: current_user, modal_pid: modal_pid}} = socket
      ) do
    template_preview = Marketing.template_preview(current_user, body_html)

    send_update(
      modal_pid,
      component,
      id: component,
      template_preview: template_preview
    )

    socket
    |> noreply()
  end

  def assign_organization(%{assigns: %{current_user: current_user}} = socket) do
    organization = Profiles.find_organization_by(user: current_user)
    socket |> assign(:organization, organization)
  end

  defp assign_campaigns(%{assigns: %{current_user: current_user}} = socket) do
    campaigns = Marketing.recent_campaigns(current_user.organization_id)
    socket |> assign(:campaigns, campaigns)
  end
end
