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
    |> assign(:uploads, nil)
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
    |> allow_upload(
      :main_image,
      accept: ~w(.jpg .png),
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
    <div class="flex-grow pb-16 md:pb-32 font-client">
      <div class="px-6 py-4 md:py-8 md:px-16 center-container flex flex-wrap justify-between items-center">
        <.logo_image uploads={@uploads} organization={@organization} edit={@edit} />
        <.book_now_button />
      </div>

      <hr class="border-base-300 center-container">

      <div class="flex flex-col justify-center px-6 mt-10 md:mt-20 md:px-16 mx-auto max-w-screen-lg">
        <.main_image edit={@edit} uploads={@uploads} image={@organization.profile.main_image} />
        <h1 class="text-2xl text-center lg:text-3xl md:text-left mt-12">About <%= @organization.name %>.</h1>
        <.description edit={@edit} description={@description} color={@color} />

        <div class="flex flex-col mb-10 mr-0 md:mr-10 md:max-w-[40%]">
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

        <%= live_component PicselloWeb.Live.Profile.ContactFormComponent, id: "contact-component", organization: @organization, color: @color, job_types: @job_types %>
      </div>
    </div>

    <.profile_footer color={@color} photographer={@photographer} organization={@organization} />

    <%= if @edit do %>
      <.edit_footer url={@url} />
    <% end %>
    """
  end

  def photo_frame(assigns) do
    ~H"""
    <div class="photo-frame-container">
      <div class="photo-frame">
        <img class="w-full" src={@url} />
      </div>
    </div>
    """
  end

  def book_now_button(assigns) do
    ~H"""
    <a href="#contact-form" class="flex items-center justify-center border border-base-300 text-sm min-w-[12rem] py-2 hover:border-base-250 hover:text-base-250">
      Book Now
      <.icon name="forth" class="ml-2 w-3 h-3 stroke-current" />
    </a>
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
  def handle_event("confirm-delete-image", %{"image-field" => image_field}, socket) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      close_label: "No! Get me out of here",
      confirm_event: "delete-" <> image_field,
      confirm_label: "Yes, delete",
      icon: "warning-orange",
      title: "Are you sure you want to delete this photo?"
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "validate-image",
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
  def handle_event(
        "validate-image",
        _params,
        %{assigns: %{uploads: %{main_image: %{entries: [entry]}}}} = socket
      ) do
    if entry.valid? do
      socket |> noreply()
    else
      socket |> cancel_upload(:main_image, entry.ref) |> noreply()
    end
  end

  @impl true
  def handle_event("validate-image", _params, socket), do: socket |> noreply()

  @impl true
  def handle_event("save-image", _params, socket) do
    socket |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "delete-" <> image_field},
        %{assigns: %{organization: organization}} = socket
      ) do
    organization = Picsello.Profiles.remove_photo(organization, String.to_atom(image_field))

    socket
    |> assign(:organization, organization)
    |> close_modal()
    |> noreply()
  end

  @impl true
  def handle_info({:update, organization}, socket) do
    socket
    |> assign_organization(organization)
    |> assign_start_prices()
    |> noreply()
  end

  @impl true
  def handle_info({:image_ready, image_field, organization}, socket) do
    consume_uploaded_entries(socket, image_field, fn _, _ -> ok(nil) end)

    socket |> assign_organization(organization) |> noreply()
  end

  defp website_url(nil), do: "#"
  defp website_url("http" <> _domain = url), do: url
  defp website_url(domain), do: "https://#{domain}"

  defp edit_image_button(assigns) do
    ~H"""
    <form id={@image_field <> "-form-existing"} phx-submit="save-image" phx-change="validate-image">
      <div class={classes("rounded-3xl bg-white shadow-lg inline-block", %{"hidden" => Enum.any?(@image.entries)})}>
        <label class="p-4 inline-block">
          <span class="text-blue-planning-300 font-bold">
            Choose a new photo
          </span>
          <%= live_file_input @image, class: "hidden" %>
        </label>
        <span phx-click="confirm-delete-image" phx-value-image-field={@image_field}>
          <.icon name="trash" class="relative bottom-1 w-5 h-5 mr-4 inline-block text-base-250" />
        </span>
      </div>
    </form>
    <.progress image={@image}/>
    """
  end

  defp drag_image_upload(assigns) do
    assigns = assigns |> Enum.into(%{class: "", label_class: ""})

    ~H"""
    <form id={"#{@image_upload.name}-form"} phx-submit="save-image" class={"flex #{@class}"} phx-change="validate-image" phx-drop-target={@image_upload.ref}>
      <label class={"w-full h-full flex items-center p-4 font-bold font-sans border border-blue-planning-300 border-2 border-dashed rounded-lg cursor-pointer #{@label_class}"}>
        <%= if @image && Enum.any?(@image_upload.entries) do %>
          <.progress image={@image_upload} class="m-4"/>
        <% else %>
          <.icon name="upload" class="w-10 h-10 mr-5 stroke-current text-blue-planning-300" />
          <div>
            Drag your <%= @image_title %> or
            <span class="text-blue-planning-300">browse</span>
            <p class="text-sm font-normal text-base-250">Supports <%= @supports %></p>
          </div>
        <% end %>
        <%= live_file_input @image_upload, class: "hidden" %>
      </label>
    </form>
    """
  end

  defp logo_image(assigns) do
    ~H"""
    <div class="flex justify-left items-center relative flex-wrap">
      <.photographer_logo organization={@organization} />
      <%= if @edit do %>
        <%= if @organization.profile.logo && @organization.profile.logo.url do %>
          <div class="my-8 sm:my-0 sm:ml-8"><.edit_image_button image={@uploads.logo} image_field={"logo"}/></div>
        <% else %>
          <p class="mx-5 text-2xl font-bold font-sans">or</p>
          <.drag_image_upload image={@organization.profile.logo} image_upload={@uploads.logo} supports="PNG or SVG" image_title="logo" />
        <% end %>
      <% end %>
    </div>
    """
  end

  defp main_image(assigns) do
    ~H"""
    <div class="relative">
      <%= case @image do %>
        <% %{url: "" <> url} -> %> <.photo_frame url={url} />
        <% _ -> %>
      <% end %>
      <%= if @edit do %>
        <%= if @image && @image.url do %>
          <div class="absolute top-8 right-8"><.edit_image_button image={@uploads.main_image} image_field={"main_image"} /></div>
        <% else %>
          <div class="bg-base-200 w-full aspect-h-1 aspect-w-2" >

            <.drag_image_upload image={@image} image_upload={@uploads.main_image} supports="JPG or PNG" image_title="main image" label_class="justify-center flex-col" class="h-5/6 w-11/12 flex m-auto" />
          </div>
        <% end %>

      <% end %>
    </div>
    """
  end

  defp progress(assigns) do
    assigns = assigns |> Enum.into(%{class: ""})

    ~H"""
    <%= for %{progress: progress} <- @image.entries do %>
      <div class={@class}>
        <div class={"w-52 h-2 rounded-lg bg-base-200"}>
          <div class="h-full bg-green-finances-300 rounded-lg" style={"width: #{progress / 2}%"}></div>
        </div>
      </div>
    <% end %>
    """
  end

  defp description(assigns) do
    ~H"""
    <div class="pt-6">
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
        <.icon_button class="mt-4 shadow-lg" title="edit description" phx-click="edit-description" color="blue-planning-300" icon="pencil">
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
