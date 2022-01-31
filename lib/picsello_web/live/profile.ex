defmodule PicselloWeb.Live.Profile do
  @moduledoc "photographers public profile"
  use PicselloWeb, live_view: [layout: "profile"]
  alias Picsello.{Profiles, Packages}

  import PicselloWeb.Live.Profile.Shared,
    only: [
      assign_organization: 2,
      assign_organization_by_slug: 2,
      photographer_logo: 1,
      profile_footer: 1
    ]

  @impl true
  def mount(%{"organization_slug" => slug}, session, socket) do
    socket
    |> assign(:edit, false)
    |> assign_defaults(session)
    |> assign_organization_by_slug(slug)
    |> assign_start_prices()
    |> maybe_redirect_slug(slug)
    |> ok()
  end

  @impl true
  def mount(params, session, socket) when map_size(params) == 0 do
    socket
    |> assign(:edit, true)
    |> assign_defaults(session)
    |> assign_current_organization()
    |> assign_start_prices()
    |> allow_upload(
      :logo,
      accept: ~w(.svg .png),
      max_entries: 1,
      external: &preflight/2,
      auto_upload: true
    )
    |> subscribe_image_process()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-grow pb-16 md:pb-32">
      <div class="px-6 py-4 md:py-8 md:px-16 center-container">
        <%= if @edit do %>
          <div class={classes("flex justify-left items-center", %{"hidden" => Enum.any?(@uploads.logo.entries)})}>
            <.photographer_logo {assigns} />
            <p class="mx-5 text-2xl font-bold">or</p>
            <form id="logo-form" phx-submit="save-logo" phx-change="validate-logo" phx-drop-target={@uploads.logo.ref}>
              <label class="flex items-center p-4 font-bold border border-blue-planning-300 border-2 border-dashed rounded-lg cursor-pointer">
                <.icon name="upload" class="w-10 h-10 mr-5 stroke-current text-blue-planning-300" />

                <div>
                  Drag your logo or
                  <span class="text-blue-planning-300">browse</span>
                  <p class="text-sm font-normal text-base-250">Supports PNG or SVG</p>
                  <%= live_file_input @uploads.logo, class: "hidden" %>
                </div>
              </label>
            </form>
          </div>
          <%= for %{progress: progress} <- @uploads.logo.entries do %>
            <div class="w-52 h-2 rounded-lg bg-base-200">
              <div class="h-full bg-green-finances-300 rounded-lg" style={"width: #{progress / 2}%"}></div>
            </div>
          <% end %>
        <% else %>
          <.photographer_logo {assigns} />
        <% end %>
      </div>

      <hr class="border-base-200">

      <div class="flex flex-col justify-center px-6 mt-10 md:mt-20 md:px-16 md:flex-row center-container">
        <div class="flex flex-col mb-10 mr-0 md:mr-10 md:max-w-[40%]">
          <h1 class="text-5xl font-bold text-center lg:text-6xl md:text-left"><%= @organization.name %></h1>

          <div>
            <div class="flex items-center mt-12">
              <h2 class="text-lg font-bold">What we offer:</h2>
              <%= if @edit do %>
                <.icon_button class="ml-5 shadow-lg" title="edit photography types" phx-click="edit-job-types" color="blue-planning-300" icon="pencil">
                  Edit Photography Types
                </.icon_button>
              <% end %>
            </div>
            <div class="w-24 h-2" style={"background-color: #{@color}"}></div>
          </div>

          <div class="w-auto">
            <%= for job_type <- @job_types do %>
              <.maybe_disabled_link edit={@edit} to={Routes.profile_pricing_job_type_path(@socket, :index, @organization.slug, job_type)} {testid("job-type")} class={classes("flex my-4 p-4 items-center rounded-lg bg-[#fafafa] border border-white", %{"hover:border-base-250" => !@edit})}>
                <.icon name={job_type} style={"color: #{@color};"} class="mr-6 fill-current w-9 h-9" />
                <dl class="flex flex-col">
                  <dt class="font-semibold whitespace-nowrap"><%= dyn_gettext job_type %></dt>
                  <%= case @start_prices[job_type] do %>
                    <% nil -> %>
                    <% price -> %>
                      <dd class="whitespace-nowrap">Starting at <%= Money.to_string(price, fractional_unit: false) %></dd>
                  <% end %>
                </dl>
              </.maybe_disabled_link>
            <% end %>
          </div>

          <.maybe_disabled_link edit={@edit} to={Routes.profile_pricing_path(@socket, :index, @organization.slug)} class={"btn-primary text-center py-2 px-8 mt-2 md:self-start"}>
            See full price list
          </.maybe_disabled_link>

          <%= if @website || @edit do %>
            <div class="flex items-center mt-auto pt-6">
              <a href={website_url(@website)} style="text-decoration-thickness: 2px" class="block pt-2 underline underline-offset-1">See our full portfolio</a>
              <%= if @edit do %>
                <.icon_button class="ml-5 shadow-lg" title="edit link" phx-click="edit-website" color="blue-planning-300" icon="pencil">
                  Edit Link
                </.icon_button>
              <% end %>
            </div>
          <% end %>
        </div>

        <div class="flex flex-col flex-grow">
          <%= if @edit || @description do %>
            <.description edit={@edit} description={@description} color={@color} />
          <% else %>
            <%= live_component PicselloWeb.Live.Profile.ContactFormComponent, id: "contact-component", organization: @organization, color: @color, job_types: @job_types %>
          <% end %>
        </div>
      </div>

      <%= if @edit || @description do %>
        <div class="flex flex-col items-center mt-8">
          <%= live_component PicselloWeb.Live.Profile.ContactFormComponent, id: "contact-component", organization: @organization, header_suffix: " with #{@organization.name}", color: @color, job_types: @job_types %>
        </div>
      <% end %>
    </div>

    <.profile_footer color={@color} photographer={@photographer} organization={@organization} />

    <%= if @edit do %>
      <.edit_footer url={@url} />
    <% end %>
    """
  end

  def maybe_disabled_link(%{edit: true} = assigns) do
    assigns =
      assigns
      |> Map.put(:rest, Map.drop(assigns, [:__changed__, :inner_block, :edit, :to]))

    ~H"""
    <div {@rest}>
      <%= render_block(@inner_block) %>
    </div>
    """
  end

  def maybe_disabled_link(assigns) do
    assigns =
      assigns
      |> Map.put(:rest, Map.drop(assigns, [:__changed__, :inner_block, :edit]))

    ~H"""
    <.live_link {@rest}>
      <%= render_block(@inner_block) %>
    </.live_link>
    """
  end

  @impl true
  def handle_event("close", %{}, socket) do
    socket
    |> push_redirect(to: Routes.profile_settings_path(socket, :index))
    |> noreply()
  end

  @impl true
  def handle_event("edit-color", %{}, socket) do
    socket |> PicselloWeb.Live.Profile.EditColorComponent.open() |> noreply()
  end

  @impl true
  def handle_event("edit-job-types", %{}, socket) do
    socket |> PicselloWeb.Live.Profile.EditJobTypeComponent.open() |> noreply()
  end

  @impl true
  def handle_event("edit-website", %{}, socket) do
    socket |> PicselloWeb.Live.Profile.EditWebsiteComponent.open() |> noreply()
  end

  @impl true
  def handle_event("edit-description", %{}, socket) do
    socket |> PicselloWeb.Live.Profile.EditDescriptionComponent.open() |> noreply()
  end

  @impl true
  def handle_event(
        "validate-logo",
        _params,
        %{assigns: %{uploads: %{logo: %{entries: [entry]}}}} = socket
      ) do
    if entry.valid? do
      socket |> noreply()
    else
      socket |> cancel_upload(:logo, entry.ref) |> noreply()
    end
  end

  @impl true
  def handle_event("validate-logo", _params, socket), do: socket |> noreply()

  @impl true
  def handle_event("save-logo", _params, socket) do
    socket |> noreply()
  end

  @impl true
  def handle_info({:update, organization}, socket) do
    socket
    |> assign_organization(organization)
    |> assign_start_prices()
    |> noreply()
  end

  @impl true
  def handle_info({:image_ready, organization}, socket) do
    consume_uploaded_entries(socket, :logo, fn _, _ -> ok(nil) end)

    socket |> assign_organization(organization) |> noreply()
  end

  defp website_url(nil), do: "#"
  defp website_url("http" <> _domain = url), do: url
  defp website_url(domain), do: "https://#{domain}"

  defp description(assigns) do
    ~H"""
    <div class="border-t-8 pt-6" style={"border-color: #{@color}"}>
      <%= if @description do %>
        <div {testid("description")} class="raw_html">
          <%= raw @description %>
        </div>
      <% else %>
        <svg width="100%" preserveAspectRatio="none" height="149" viewBox="0 0 561 149" fill="none" xmlns="http://www.w3.org/2000/svg">
          <rect width="561" height="21" fill="#F6F6F6"/>
          <rect y="32" width="487" height="21" fill="#F6F6F6"/>
          <rect y="64" width="518" height="21" fill="#F6F6F6"/>
          <rect y="96" width="533" height="21" fill="#F6F6F6"/>
          <rect y="128" width="445" height="21" fill="#F6F6F6"/>
        </svg>
      <% end %>
      <%= if @edit do %>
        <.icon_button class="mt-6 shadow-lg" title="edit description" phx-click="edit-description" color="blue-planning-300" icon="pencil">
          Edit Description
        </.icon_button>
      <% end %>
    </div>
    """
  end

  defp edit_footer(assigns) do
    ~H"""
    <div class="mt-32"></div>
    <div class="fixed bottom-0 left-0 right-0 bg-base-300 z-20">
      <div class="center-container px-6 md:px-16 py-2 sm:py-4 flex flex-col-reverse sm:flex-row justify-between">
        <button class="btn-primary my-2 border-white w-full sm:w-auto" title="close" type="button" phx-click="close">
          Close
        </button>
        <div class="flex flex-row-reverse gap-4 sm:flex-row justify-between">
          <button class="btn-primary my-2 border-white ml-auto w-full sm:w-auto" title="change color" type="button" phx-click="edit-color">
            Change color
          </button>
          <a href={@url} class="btn-secondary my-2 w-full sm:w-auto hover:bg-base-200 text-center" target="_blank" rel="noopener noreferrer">
            View
          </a>
        </div>
      </div>
    </div>
    """
  end

  defp preflight(image, %{assigns: %{organization: organization}} = socket) do
    {:ok, meta, organization} = Profiles.preflight(image, organization)
    {:ok, meta, assign(socket, organization: organization)}
  end

  defp assign_current_organization(%{assigns: %{current_user: current_user}} = socket) do
    organization = Profiles.find_organization_by(user: current_user)
    assign_organization(socket, organization)
  end

  defp assign_start_prices(%{assigns: %{organization: organization}} = socket) do
    start_prices =
      Packages.templates_for_organization(organization)
      |> Enum.group_by(& &1.job_type)
      |> Enum.map(fn {job_type, packages} ->
        min_price = packages |> Enum.map(&Packages.price/1) |> Enum.sort() |> hd
        {job_type, min_price}
      end)
      |> Enum.into(%{})

    socket |> assign(:start_prices, start_prices)
  end

  defp maybe_redirect_slug(%{assigns: %{organization: organization}} = socket, current_slug) do
    if current_slug != organization.slug do
      push_redirect(socket, to: Routes.profile_path(socket, :index, organization.slug))
    else
      socket
    end
  end

  defp subscribe_image_process(%{assigns: %{organization: organization}} = socket) do
    Profiles.subscribe_to_photo_processed(organization)

    socket
  end
end
