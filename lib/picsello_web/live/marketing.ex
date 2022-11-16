defmodule PicselloWeb.Live.Marketing do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Repo, Marketing, Profiles, BrandLink}

  @impl true
  def mount(params, _session, socket) do
    socket
    |> is_mobile(params)
    |> assign(:page_title, "Marketing")
    |> assign_attention_items()
    |> assign_organization()
    |> assign_brand_links()
    |> assign_campaigns()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div {intro(@current_user, "intro_marketing")}>
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
                    <h3 class="text-lg font-bold">
                      <.icon name={icon} width="23" height="20" class={"inline-block mr-2 rounded-sm fill-current bg-blue-planning-100 text-#{color}"} />
                      <%= title %>
                    </h3>
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
      <div class="px-6 center-container">
        <div class="my-12">
          <.card title="Brand links" class="relative intro-brand-links">
            <div class="flex items-center flex-wrap justify-between">
              <%= if active?(@brand_links) do %>
                <p class="lg:flex hidden">Add links to your web platforms so you can quickly open them to login or use them in your marketing emails.</p>
                <p class="lg:hidden mb-5">Add links to your web platforms so you can quickly open them from your Marketing Hub.</p>
              <% else %>
                <p class="lg:flex hidden">Looks like you don’t have any links. Go head and add one!</p>
                <p class="lg:hidden mb-5">Add links to your web platforms so you can quickly open them from your Marketing Hub.</p>
              <% end %>
              <button type="button" phx-click="edit-link" phx-value-link-id="website" class="w-full sm:w-auto text-center btn-primary">Manage links</button>
            </div>
            <div id="marketing-links" class={classes("hiddden gap-5 mt-10 lg:grid-cols-4 md:grid-cols-2 grid-cols-1", %{"grid" => active?(@brand_links)})}>
              <%= case @brand_links do %>
                <% [] -> %>
                <% brand_links -> %>
                <%= for %{title: title, link: link, link_id: link_id, active?: active?} <- brand_links do %>
                  <div {testid("marketing-links")} class={classes("flex items-center mb-4", %{"hidden" => !active?})}>
                    <div class="flex items-center justify-center w-20 h-20 ml-1 mr-3 rounded-full flex-shrink-0 bg-base-200 p-6">
                      <.icon name={get_brand_link_icon(link_id)} />
                    </div>
                    <div>
                      <h4 class="text-xl font-bold mb-2"><a href={link} target="_blank" rel="noopener noreferrer"><%= title %></a></h4>
                      <div class="flex">
                        <%= if link do %>
                          <a href={link} target="_blank" rel="noopener noreferrer" class="px-1 pb-1 font-bold bg-white border rounded-lg border-blue-planning-300 text-blue-planning-300 hover:bg-blue-planning-100">Open</a>
                        <% end %>
                        <button phx-click="edit-link" phx-value-link-id={link_id} class="ml-2 text-blue-planning-300 underline">Edit</button>
                      </div>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          </.card>
        </div>
        <.card title="Marketing Emails" class={classes("relative", %{"sm:col-span-2" => Enum.any?(@campaigns)})}>
          <p class="mb-8">Send marketing campaigns to your current/past and new clients.</p>
          <div class="p-4 border rounded">
            <header class="flex items-center flex-wrap justify-between">
              <div class="flex items-center lg:mb-0 mb-4">
                <.icon name="camera-check" class="text-purple-marketing-300 w-12 h-12 mr-4" />
                <h3 class="text-xl font-bold intro-promotional">Promote your business</h3>
              </div>
              <button type="button" phx-click="new-campaign" class="w-full sm:w-auto text-center btn-primary">Create an email</button>
            </header>
            <%= unless Enum.empty?(@campaigns) do %>
              <h2 class="mt-4 mb-4 text-sm font-bold tracking-widest text-gray-400 uppercase">Most Recent</h2>
              <ul class="text-left grid gap-5 lg:grid-cols-3 md:grid-cols-2 grid-cols-1">
                <%= for campaign <- @campaigns do %>
                  <.campaign_item id={campaign.id} subject={campaign.subject} date={strftime(@current_user.time_zone, campaign.inserted_at, "%B %d, %Y")} clients_count={campaign.clients_count} />
                <% end %>
              </ul>
            <% end %>
          </div>
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
        <h1 class="text-2xl font-bold mb-2"><%= @title %></h1>

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
  def handle_event("edit-link", %{"link-id" => link_id}, socket) do
    socket |> PicselloWeb.Live.Marketing.EditLinkComponent.open(link_id) |> noreply()
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

  def handle_info(
        {:update_brand_links, brand_links, message},
        %{assigns: %{organization: organization}} = socket
      ) do
    socket
    |> assign(:organization, Map.put(organization, :brand_links, brand_links))
    |> assign_brand_links()
    |> put_flash(:success, "Link #{message}")
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

  def assign_brand_links(
        %{assigns: %{organization: %{id: organization_id, brand_links: brand_links}}} = socket
      ) do
    preset_brand_links = [
      %BrandLink{
        title: "Website",
        link: nil,
        link_id: "website",
        organization_id: organization_id
      },
      %BrandLink{
        title: "Instagram",
        link: "https://www.instagram.com/",
        link_id: "instagram",
        organization_id: organization_id
      },
      %BrandLink{
        title: "Twitter",
        link: "https://www.twitter.com/",
        link_id: "twitter",
        organization_id: organization_id
      },
      %BrandLink{
        title: "TikTok",
        link: "https://www.tiktok.com/",
        link_id: "tiktok",
        organization_id: organization_id
      },
      %BrandLink{
        title: "Facebook",
        link: "https://www.facebook.com/",
        link_id: "facebook",
        organization_id: organization_id
      },
      %BrandLink{
        title: "Google Reviews",
        link: "https://www.google.com/business",
        link_id: "google-business",
        organization_id: organization_id
      },
      %BrandLink{
        title: "Linkedin",
        link: "https://www.linkedin.com/",
        link_id: "linkedin",
        organization_id: organization_id
      },
      %BrandLink{
        title: "Pinterest",
        link: "https://www.pinterest.com/",
        link_id: "pinterest",
        organization_id: organization_id
      },
      %BrandLink{
        title: "Yelp",
        link: "https://www.yelp.com/",
        link_id: "yelp",
        organization_id: organization_id
      },
      %BrandLink{
        title: "Snapchat",
        link: "https://www.snapchat.com/",
        link_id: "snapchat",
        organization_id: organization_id
      }
    ]

    socket
    |> assign(:brand_links, map_brand_links(preset_brand_links, brand_links))
  end

  defp map_brand_links(preset_brand_links, []), do: preset_brand_links

  defp map_brand_links(preset_brand_links, brand_links) do
    [presets | custom] =
      brand_links |> Enum.group_by(&String.contains?(&1.link_id, "link_")) |> Map.values()

    Enum.reduce(preset_brand_links, [], fn preset_brand_link, acc ->
      Enum.find(presets, fn brand_link ->
        brand_link.link_id == preset_brand_link.link_id
      end)
      |> case do
        nil -> [preset_brand_link | acc]
        _ -> acc
      end
    end) ++
      presets ++ Enum.with_index(List.flatten(custom), &Map.put(&1, :link_id, "link_#{&2 + 1}"))
  end

  def assign_attention_items(socket) do
    items = [
      %{
        action: "public-profile",
        title: "Review your Public Profile",
        body:
          "We highly suggest you review your Picsello Public Profile. We provide options to insert links into your emails (wardrobe guide, pricing, etc)",
        icon: "bullhorn",
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
        icon: "bullhorn",
        button_label: "Check out our blog",
        button_class: "btn-secondary",
        external_link: "https://www.picsello.com/post/top-10-tips-seo-for-photographers",
        color: "purple-marketing-300",
        class: "border-purple-marketing-300"
      }
    ]

    socket |> assign(:attention_items, items)
  end

  def assign_organization(%{assigns: %{current_user: current_user}} = socket) do
    organization =
      Profiles.find_organization_by(user: current_user) |> Repo.preload(:brand_links, force: true)

    socket |> assign(:organization, organization)
  end

  defp assign_campaigns(%{assigns: %{current_user: current_user}} = socket) do
    campaigns = Marketing.recent_campaigns(current_user.organization_id)
    socket |> assign(:campaigns, campaigns)
  end

  defp active?(brand_links), do: brand_links |> Enum.any?(& &1.active?)
end
