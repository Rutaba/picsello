defmodule PicselloWeb.Live.Profile do
  @moduledoc "photographers public profile"
  use PicselloWeb, live_view: [layout: "profile"]
  alias Picsello.{Profiles, Packages, Subscriptions}
  alias Picsello.BookingEvents

  import PicselloWeb.ClientBookingEventLive.Shared,
    only: [
      blurred_thumbnail: 1,
      date_display: 1,
      address_display: 1,
      subtitle_display: 1,
      formatted_date: 1
    ]

  import PicselloWeb.Shared.StickyUpload, only: [sticky_upload: 1]

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
    |> assign(:entry, nil)
    |> assign_defaults(session)
    |> assign_organization_by_slug(slug)
    |> assign_booking_events()
    |> assign_job_type_packages()
    |> maybe_redirect_slug(slug)
    |> check_active_subscription()
    |> ok()
  end

  @impl true
  def mount(params, session, socket) when map_size(params) == 0 do
    socket
    |> assign(:edit, true)
    |> assign(:entry, nil)
    |> assign_defaults(session)
    |> assign_current_organization()
    |> assign_booking_events()
    |> assign_job_type_packages()
    |> allow_upload(
      :logo,
      accept: ~w(.svg .png),
      max_file_size: String.to_integer(Application.get_env(:picsello, :logo_max_size)),
      max_entries: 1,
      external: &preflight/2,
      auto_upload: true
    )
    |> allow_upload(
      :main_image,
      accept: ~w(.jpg .png),
      max_file_size: String.to_integer(Application.get_env(:picsello, :logo_max_size)),
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
    <div class="flex-grow center-container client-app">
      <.sticky_upload current_user={@current_user} />
      <div class="flex flex-wrap items-center justify-between px-6 py-2 md:py-4 md:px-12">
        <.logo_image icon_class={select_icon_class(@entry, @entry && @entry.upload_config == :logo)} uploads={@uploads} organization={@organization} edit={@edit} />
        <.book_now_button />
      </div>

      <hr class="border-base-200 mt-2">

      <div class="flex flex-col justify-center max-w-screen-lg px-6 mx-auto mt-10 md:px-16">
        <.main_image icon_class={select_icon_class(@entry, @entry && @entry.upload_config == :main_image)} edit={@edit} uploads={@uploads} image={@organization.profile.main_image} />
        <h1 class="mt-12 text-2xl text-center lg:text-3xl md:text-left">About <%= @organization.name %>.</h1>

        <.job_types_details edit={@edit} job_types={@job_types} job_types_description={@job_types_description} />

        <.rich_text_content edit={@edit} field_name="description" field_value={@description} />

        <%= if @website || @edit do %>
          <div class="flex items-center py-6">
            <a href={website_url(@website)} style="text-decoration-thickness: 2px" class="block pt-2 underline underline-offset-1">See our full portfolio</a>
            <%= if @edit do %>
              <.icon_button {testid("edit-link-button")} class="ml-5 shadow-lg" title="edit link" phx-click="edit-website" color="blue-planning-300" icon="pencil">
                Edit Link
              </.icon_button>
            <% end %>
          </div>
        <% end %>

        <hr class="mt-12" />

        <%= if Enum.any?(@booking_events) do %>
          <section class="mt-20">
            <h2 class="text-4xl font-bold mb-8" {testid("events-heading")}>Book a session with me!</h2>
            <div class="grid sm:grid-cols-2 gap-8">
              <%= for event <- @booking_events do %>
                <div {testid("booking-cards")}>
                  <a href={"#{event.url}/book"} class="block w-full col">
                    <.blurred_thumbnail class="w-full" url={event.thumbnail_url} />
                    <div>
                      <h3 class="text-xl font-semibold mt-4">
                        <%= event.name %>
                      </h3>
                      <.subtitle_display booking_event={event} package={event.package_template} class="text-base-250 mt-2" />
                      <div class="mt-4 flex flex-col border-gray-100 border-y py-4 text-base-250">
                        <.date_display date={formatted_date(event)} />
                        <.address_display booking_event={event} class="mt-4"/>
                      </div>
                      <div class="my-4 raw_html"><%= raw event.description %></div>
                      <button type="button" class="flex items-center justify-center btn-primary">
                        Book now
                      </button>
                    </div>
                  </a>
                </div>
              <% end %>
            </div>
          </section>
        <% end %>

        <h3 class="mt-20 uppercase font-bold">MORE ABOUT MY OFFERINGS:</h3>
        <.rich_text_content edit={@edit} field_name="job_types_description" field_value={@job_types_description} />

        <hr class="mt-12" />

        <h3 class="mt-20 uppercase font-bold">PRICING & SERVICES:</h3>

        <%= for {job_type, packages} <- @job_type_packages do %>
          <h2 class="mt-10 text-2xl text-center" id={to_string(job_type)}><%= dyn_gettext job_type %></h2>
          <%= for package <- packages do %>
            <.package_detail name={package.name} price={Packages.price(package)} description={package.description} download_count={package.download_count} />
          <% end %>
          <div class="flex justify-center my-4">
            <.book_now_button job_type={job_type} />
          </div>
        <% end %>

        <hr class="my-20" />

        <%= live_component PicselloWeb.Live.Profile.ClientFormComponent, id: "client-component", organization: @organization, color: @color, job_types: @job_types, job_type: @job_type %>
      </div>

      <.profile_footer color={@color} photographer={@photographer} organization={@organization} />
    </div>


    <%= if @edit do %>
      <.edit_footer url={@url} />
    <% end %>
    """
  end

  def job_types_details(assigns) do
    ~H"""
    <div class="flex items-center mt-8">
      <h3 class="uppercase font-bold">Specializing In:</h3>
    </div>

    <div class="w-auto mt-4">
      <%= @job_types |> Enum.with_index |> Enum.map(fn({job_type, i}) -> %>
        <%= if i > 0 do %><span>&nbsp;|&nbsp;</span><% end %>
        <span {testid("job-type")} class="text-xl whitespace-nowrap"><%= dyn_gettext job_type %></span>
      <% end) %>
    </div>
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
    assigns = assigns |> Enum.into(%{job_type: nil})

    ~H"""
    <a href="#contact-form" class="flex items-center justify-center btn-primary" phx-click="select-job-type" phx-value-job-type={@job_type}>
      Book Now
    </a>
    """
  end

  @impl true
  def handle_event("close", %{}, socket) do
    socket
    |> push_redirect(to: Routes.profile_settings_path(socket, :index))
    |> noreply()
  end

  @impl true
  def handle_event("select-job-type", %{"job-type" => job_type}, socket) do
    socket
    |> assign(:job_type, job_type)
    |> noreply()
  end

  @impl true
  def handle_event("select-job-type", %{}, socket), do: socket |> noreply()

  @impl true
  def handle_event("edit-job-types", %{}, socket) do
    socket |> PicselloWeb.PackageLive.EditJobTypeComponent.open() |> noreply()
  end

  @impl true
  def handle_event("edit-website", %{}, socket) do
    socket |> PicselloWeb.Live.Profile.EditWebsiteComponent.open() |> noreply()
  end

  @impl true
  def handle_event("edit-text-field-description", %{"field-name" => field_name}, socket) do
    socket |> PicselloWeb.Live.Profile.EditDescriptionComponent.open(field_name) |> noreply()
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
    socket
    |> validate_entry(entry)
    |> assign(:entry, entry)
    |> noreply()
  end

  @impl true
  def handle_event(
        "validate-image",
        _params,
        %{assigns: %{uploads: %{main_image: %{entries: [entry]}}}} = socket
      ) do
    socket
    |> validate_entry(entry)
    |> assign(:entry, entry)
    |> noreply()
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
    |> assign_job_type_packages()
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

  defp assign_booking_events(%{assigns: %{organization: organization}} = socket) do
    booking_events =
      BookingEvents.get_booking_events_public(organization.id)
      |> Enum.map(fn booking_event ->
        booking_event
        |> Map.put(
          :url,
          Routes.client_booking_event_url(
            socket,
            :show,
            organization.slug,
            booking_event.id
          )
        )
      end)

    socket
    |> assign(booking_events: booking_events)
  end

  defp edit_image_button(assigns) do
    ~H"""
    <form id={@image_field <> "-form-existing"} phx-submit="save-image" phx-change="validate-image">
      <div class={classes("rounded-3xl bg-white shadow-lg inline-block", %{"hidden" => Enum.any?(@image.entries)})}>
        <label class="inline-block p-3 cursor-pointer">
          <span class="font-sans font-semibold text-blue-planning-300 hover:opacity-75">
            Choose a new photo
          </span>
          <%= live_file_input @image, class: "hidden" %>
        </label>
        <span phx-click="confirm-delete-image" phx-value-image-field={@image_field} class="cursor-pointer">
          <.icon name="trash" class="relative inline-block w-5 h-5 mr-4 bottom-1 text-base-250 hover:opacity-75" />
        </span>
      </div>
    </form>
    <.progress image={@image}/>
    """
  end

  defp drag_image_upload(assigns) do
    assigns = assigns |> Enum.into(%{class: "", label_class: "", supports_class: ""})

    ~H"""
    <form id={"#{@image_upload.name}-form"} phx-submit="save-image" class={"flex #{@class}"} phx-change="validate-image" phx-drop-target={@image_upload.ref}>
      <label class={"w-full h-full flex items-center p-4 font-bold font-sans border border-#{@icon_class} border-2 border-dashed rounded-lg cursor-pointer #{@label_class}"}>
        <%= if @image && Enum.any?(@image_upload.entries) do %>
          <.progress image={@image_upload} class="m-4"/>
        <% else %>
          <.icon name="upload" class={"w-10 h-10 mr-5 stroke-current text-#{@icon_class}"} />
          <div class={@supports_class}>
            Drag your <%= @image_title %> or
            <span class={"text-#{@icon_class}"}>browse</span>
            <p class="text-sm font-normal text-base-250">Supports <%= @supports %></p>
          </div>
        <% end %>
        <%= live_file_input @image_upload, class: "hidden" %>
      </label>
    </form>
    """
  end

  defp select_icon_class(%{valid?: false}, true), do: "red-sales-300"
  defp select_icon_class(_entry, _), do: "blue-planning-300"

  defp logo_image(assigns) do
    ~H"""
    <div class="relative flex flex-wrap items-center justify-left">
      <.photographer_logo organization={@organization} />
      <%= if @edit do %>
        <%= if @organization.profile.logo && @organization.profile.logo.url do %>
          <div class="my-8 sm:my-0 sm:ml-8"><.edit_image_button image={@uploads.logo} image_field={"logo"}/></div>
        <% else %>
          <p class="mx-5 font-sans text-2xl font-bold">or</p>
          <.drag_image_upload icon_class={@icon_class} image={@organization.profile.logo} image_upload={@uploads.logo} supports="PNG or SVG: under 10 mb" image_title="logo" />
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
          <div class="bg-[#F6F6F6] w-full aspect-[2/1] flex items-center justify-center">
            <.drag_image_upload icon_class={@icon_class} image={@image} image_upload={@uploads.main_image} supports_class="text-center" supports="JPEG or PNG: 1060x650 under 10mb" image_title="main image" label_class="justify-center flex-col" class="h-5/6 w-11/12 flex m-auto" />
          </div>
        <% end %>

      <% end %>
    </div>
    """
  end

  defp package_detail(assigns) do
    ~H"""
    <div {testid("package-detail")}>
      <div class="flex justify-between text-xl pt-14">
        <div><%= @name %></div>
        <div><%= Money.to_string(@price, fractional_unit: false) %></div>
      </div>

      <div class="mt-4 whitespace-pre-line raw_html"><%=raw @description %></div>
    </div>
    """
  end

  defp progress(assigns) do
    assigns = assigns |> Enum.into(%{class: ""})

    ~H"""
    <%= for %{progress: progress} <- @image.entries do %>
      <div class={@class}>
        <div class={"w-52 h-2 rounded-lg bg-base-200"}>
          <div class="h-full rounded-lg bg-green-finances-300" style={"width: #{progress / 2}%"}></div>
        </div>
      </div>
    <% end %>
    """
  end

  defp rich_text_content(assigns) do
    ~H"""
    <div class="pt-6">
      <%= if @field_value do %>
        <div {testid(@field_name)} class="raw_html">
          <%= raw @field_value %>
        </div>
      <% end %>
      <%= if @edit do %>
        <%= if !@field_value do %>
          <svg width="100%" preserveAspectRatio="none" height="149" viewBox="0 0 561 149" fill="none" xmlns="http://www.w3.org/2000/svg">
            <rect width="561" height="21" fill="#F6F6F6"/>
            <rect y="32" width="487" height="21" fill="#F6F6F6"/>
            <rect y="64" width="518" height="21" fill="#F6F6F6"/>
            <rect y="96" width="533" height="21" fill="#F6F6F6"/>
            <rect y="128" width="445" height="21" fill="#F6F6F6"/>
          </svg>
        <% end %>
        <.icon_button {testid("edit-#{@field_name}-button")} class="mt-4 shadow-lg" title="edit description" phx-click="edit-text-field-description" phx-value-field-name={@field_name} color="blue-planning-300" icon="pencil">
          Edit Description
        </.icon_button>
      <% end %>
    </div>
    """
  end

  defp edit_footer(assigns) do
    ~H"""
    <div class="mt-32"></div>
    <div class="fixed bottom-0 left-0 right-0 z-20 bg-base-300">
      <div class="flex flex-col-reverse justify-between px-6 py-2 center-container md:px-16 sm:py-4 sm:flex-row">
        <button class="w-full my-2 border-white btn-primary sm:w-auto" title="close" type="button" phx-click="close">
          Close
        </button>
        <div class="flex flex-row-reverse justify-between gap-4 sm:flex-row">
          <a href={@url} class="w-full my-2 text-center btn-secondary sm:w-auto hover:bg-base-200" target="_blank" rel="noopener noreferrer">
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

  defp assign_job_type_packages(
         %{assigns: %{organization: organization, job_types: job_types}} = socket
       ) do
    {packages, _} =
      Packages.templates_for_organization(organization)
      |> Enum.group_by(& &1.job_type)
      |> Map.split(job_types)

    socket |> assign(:job_type_packages, packages) |> assign(:job_type, nil)
  end

  defp maybe_redirect_slug(%{assigns: %{organization: organization}} = socket, current_slug) do
    if current_slug != organization.slug do
      push_redirect(socket, to: Routes.profile_path(socket, :index, organization.slug))
    else
      socket
    end
  end

  defp check_active_subscription(%{assigns: %{organization: organization}} = socket) do
    Subscriptions.ensure_active_subscription!(organization.user)

    socket
  end

  defp subscribe_image_process(%{assigns: %{organization: organization}} = socket) do
    Profiles.subscribe_to_photo_processed(organization)

    socket
  end

  defp validate_entry(socket, %{valid?: valid} = entry) do
    if valid do
      socket
    else
      socket
      |> put_flash(:error, "Image was too large, needs to be below 10 mb")
      |> cancel_upload(entry.upload_config, entry.ref)
    end
  end
end
