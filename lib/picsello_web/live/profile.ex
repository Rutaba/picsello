defmodule PicselloWeb.Live.Profile do
  @moduledoc "photographers public profile"
  use PicselloWeb, live_view: [layout: "profile"]
  alias Picsello.{Profiles}

  @impl true
  def mount(%{"organization_slug" => slug}, session, socket) do
    socket
    |> assign(:edit, false)
    |> assign_defaults(session)
    |> assign_organization_by_slug(slug)
    |> assign_contact_changeset()
    |> ok()
  end

  @impl true
  def mount(params, session, socket) when map_size(params) == 0 do
    socket
    |> assign(:edit, true)
    |> assign_defaults(session)
    |> assign_current_organization()
    |> assign_contact_changeset()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-grow border-b-8 pb-16 md:pb-32" style={"border-color: #{@color}"}>
      <div class="px-6 py-4 md:py-8 md:px-16 center-container">
        <.default_logo color={@color} photographer={@photographer} />
      </div>

      <hr class="border-base-200">

      <div class="flex flex-col justify-center px-6 mt-10 md:mt-20 md:px-16 md:flex-row center-container">
        <div class="mb-10 mr-0 md:mr-10">
          <h1 class="text-5xl font-bold text-center lg:text-6xl md:text-left"><%= @organization.name %></h1>

          <div class="flex items-center mt-12">
            <h2 class="text-lg font-bold">What we offer:</h2>
            <%= if @edit do %>
              <.icon_button class="ml-5 shadow-lg" title="edit photography types" phx-click="edit-job-types" color="blue-planning-300" icon="pencil">
                Edit Photography Types
              </.icon_button>
            <% end %>
          </div>

          <div class="w-1/4 h-2" style={"background-color: #{@color}"}></div>

          <div class="w-auto md:w-min">
            <%= for job_type <- @job_types do %>
              <div {testid("job-type")} class="flex my-4 p-4 items-center font-semibold rounded-lg bg-[#fafafa]">
                <.icon name={job_type} style={"color: #{@color};"} class="mr-6 fill-current w-9 h-9" />

                <span class="whitespace-nowrap"><%= dyn_gettext job_type %></span>
              </div>
            <% end %>
          </div>

          <%= if @website || @edit do %>
            <div class="flex items-center">
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
            <.contact_form color={@color} contact_changeset={@contact_changeset} job_types={@job_types} />
          <% end %>
        </div>
      </div>

      <%= if @edit || @description do %>
        <div class="flex flex-col items-center mt-8">
          <.contact_form header_suffix={" with #{@organization.name}"} color={@color} contact_changeset={@contact_changeset} job_types={@job_types} />
        </div>
      <% end %>
    </div>

    <footer class="px-6 md:px-16 center-container">
      <div class="flex justify-center py-8 md:justify-start md:py-14"><.default_logo color={@color} photographer={@photographer} /></div>

      <div class="flex flex-col items-center justify-start pt-6 mb-8 border-t md:flex-row md:justify-between border-base-250 text-base-300 opacity-30">
        <span>© <%= Date.utc_today().year %> <%= @organization.name %></span>

        <span class="mt-2 md:mt-0">Powered By <a href="https://www.picsello.com/?utm_source=app&utm_medium=link&utm_campaign=public_profile&utm_contentType=landing_page&utm_content=footer_link&utm_audience=existing_user" target="_blank">Picsello</a></span>
      </div>
    </footer>

    <%= if @edit do %>
      <.edit_footer url={@url} />
    <% end %>
    """
  end

  @impl true
  def handle_event("validate-contact", %{"contact" => params}, socket) do
    socket
    |> assign(
      contact_changeset: params |> Profiles.contact_changeset() |> Map.put(:action, :validate)
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "save-contact",
        %{"contact" => params},
        %{assigns: %{organization: organization}} = socket
      ) do
    case Profiles.handle_contact(organization, params) do
      {:ok, _contact} ->
        socket
        |> assign(contact_changeset: nil)
        |> noreply()

      {:error, changeset} ->
        socket |> assign(contact_changeset: changeset) |> noreply()
    end
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
  def handle_info({:update, organization}, socket) do
    socket
    |> assign_organization(organization)
    |> noreply()
  end

  defp website_url(nil), do: "#"
  defp website_url("http" <> _domain = url), do: url
  defp website_url(domain), do: "https://#{domain}"

  defp default_logo(assigns) do
    ~H"""
      <.initials_circle style={"background-color: #{@color}"} class="pb-1 text-2xl font-bold w-14 h-14 text-base-100" user={@photographer} />
    """
  end

  defp contact_form(assigns) do
    assigns = assigns |> Enum.into(%{header_suffix: ""})

    ~H"""
    <div class="border rounded-lg p-9 border-base-200">
      <h2 class="text-3xl font-bold max-w-md">Get in touch<%= @header_suffix %></h2>

      <div class="w-1/3 h-2 mt-4 lg:w-1/4" style={"background-color: #{@color}"}></div>

      <%= if @contact_changeset do %>
        <.form for={@contact_changeset} let={f} phx-change="validate-contact" phx-submit="save-contact" >
          <div class="flex flex-col mt-3">
            <%= label_for f, :name, autocapitalize: "words", autocorrect: "false", spellcheck: "false", autocomplete: "name", label: "Your name", class: "py-2 font-bold" %>

            <%= input f, :name, placeholder: "Type your first and last name...", class: "p-5", phx_debounce: 300 %>
          </div>

          <div class="flex flex-col lg:flex-row">
            <div class="flex flex-col flex-1 mt-3 mr-0 lg:mr-4">
              <%= label_for f, :email, label: "Your email", class: "py-2 font-bold" %>

              <%= input f, :email, type: :email_input, placeholder: "Type email...", class: "p-5", phx_debounce: 300 %>
            </div>

            <div class="flex flex-col flex-1 mt-3">
              <%= label_for f, :phone, label: "Your phone number", class: "py-2 font-bold" %>

              <%= input f, :phone, type: :telephone_input, placeholder: "Type phone number...", class: "p-5", phx_debounce: 300, phx_hook: "Phone" %>
            </div>
          </div>

          <div class="mt-7 grid grid-cols-1 lg:grid-cols-2 gap-4">
            <%= label_for f, :job_type, label: "What photography type are you interested in?", class: "py-2 font-bold col-span-1 lg:col-span-2" %>

            <%= for job_type <- @job_types do %>
              <.job_type_option name={input_name(f, :job_type)} type={:radio} job_type={job_type} checked={input_value(f, :job_type) == job_type} />
            <% end %>
          </div>

          <div class="flex flex-col mt-7">
            <%= label_for f, :message, label: "Your message", class: "py-2 font-bold" %>

            <%= input f, :message, type: :textarea, placeholder: "Type your message...", class: "p-5", rows: 5, phx_debounce: 300 %>
          </div>

          <div class="mt-8 text-right"><button class="w-full lg:w-auto btn-primary">Submit</button></div>
        </.form>
      <% else %>
        <div class="flex items-center mt-14 min-w-max">
          <.icon name="confetti" class="w-20 h-20 stroke-current mr-9" style={"color: #{@color}"} />
          <div>
            <h2 class="text-2xl font-bold">Message sent</h2>
            We'll contact you soon!
          </div>
        </div>
      <% end %>
    </div>
    """
  end

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

  defp assign_organization_by_slug(socket, slug) do
    organization = Profiles.find_organization_by(slug: slug)
    assign_organization(socket, organization)
  end

  defp assign_current_organization(%{assigns: %{current_user: current_user}} = socket) do
    organization = Profiles.find_organization_by(user: current_user)
    assign_organization(socket, organization)
  end

  defp assign_organization(socket, organization) do
    %{profile: profile, user: user} = organization

    assign(socket,
      organization: organization,
      color: profile.color,
      description: profile.description,
      website: profile.website,
      photographer: user,
      job_types: profile.job_types,
      url: Profiles.public_url(organization)
    )
  end

  defp assign_contact_changeset(%{assigns: %{job_types: types}} = socket) do
    params =
      case types do
        [job_type] -> %{job_type: job_type}
        _ -> %{}
      end

    assign(socket, :contact_changeset, Profiles.contact_changeset(params))
  end
end
