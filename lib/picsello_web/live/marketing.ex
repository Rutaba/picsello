defmodule PicselloWeb.Live.Marketing do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Marketing, Profiles}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Marketing")
    |> assign_attention_items()
    |> assign_organization()
    |> assign_campaigns()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="bg-gray-100">
      <div class="pt-10 pb-8 center-container">
        <h1 class="px-6 text-4xl font-bold">Marketing</h1>
        <%= case @attention_items do %>
        <% [] -> %>
        <% items -> %>
          <h2 class="px-6 mt-8 mb-4 text-sm font-bold tracking-widest text-gray-400 uppercase">Next Up</h2>
          <ul class="flex px-6 pb-4 overflow-auto lg:pb-0 lg:overflow-none intro-next-up">
            <%= for %{title: title, body: body, icon: icon, button_label: button_label, button_class: button_class, color: color, action: action, class: class, external_link: external_link} <- items do %>
            <li {testid("marketing-attention-item")} class={"flex-shrink-0 flex lg:flex-1 flex-col justify-between max-w-sm w-3/4 p-5 cursor-pointer mr-4 border rounded-lg #{class} bg-white border-gray-250"}>
              <div>
                <h1 class="text-lg font-bold">
                  <.icon name={icon} width="23" height="20" class={"inline-block mr-2 rounded-sm fill-current bg-blue-planning-100 text-#{color}"} />
                  <%= title %>
                </h1>

                <p class="my-2 text-sm"><%= body %></p>

                <%= case action do %>
                  <% "public-profile" -> %>
                    <button type="button" phx-click={action} class={"#{button_class} text-sm w-full py-2 mt-2"}><%= button_label %></button>
                  <% _ -> %>
                    <a href={external_link} class={"#{button_class} text-center text-sm w-full py-2 mt-2 inline-block"} target="_blank" rel="noopener noreferrer">
                      <%= button_label %>
                    </a>
                <% end %>
              </div>
            </li>
            <% end %>
          </ul>
      <% end %>
      </div>
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
  def handle_event("public-profile", %{}, socket),
    do:
      socket
      |> push_redirect(to: Routes.profile_settings_path(socket, :index))
      |> noreply()

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

  def assign_attention_items(socket) do
    items = [
      %{
        action: "public-profile",
        title: "Review your Public Profile",
        body:
          "We highly suggest you review your Picsello Public Profile. We provide options to insert links into your emails (wardrobe guide, pricing, etc)",
        icon: "three-people",
        button_label: "Take me to settings",
        button_class: "btn-secondary",
        external_link: "",
        color: "purple-marketing-300",
        class: "border-purple-marketing-300"
      },
      %{
        action: "external-link",
        title: "Marketing tip: SEO",
        body:
          "Google loves their own products. Rank higher in search by adding a YouTube Video or Google Maps to your website!",
        icon: "three-people",
        button_label: "Check out our blog",
        button_class: "btn-secondary",
        external_link:
          "https://www.picsello.com/post/best-business-resources-for-new-photographers",
        color: "purple-marketing-300",
        class: "border-purple-marketing-300"
      },
      %{
        action: "external-link",
        title: "Marketing tip: SEO",
        body:
          "Setup Google My Business if you haven’t already and ask for more reviews—they really help your search results!",
        icon: "three-people",
        button_label: "Check out our blog",
        button_class: "btn-secondary",
        external_link:
          "https://www.picsello.com/post/best-business-resources-for-new-photographers",
        color: "purple-marketing-300",
        class: "border-purple-marketing-300"
      }
    ]

    socket |> assign(:attention_items, items)
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
