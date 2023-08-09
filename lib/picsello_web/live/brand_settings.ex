defmodule PicselloWeb.Live.BrandSettings do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.User.Settings, only: [settings_nav: 1, card: 1]

  import PicselloWeb.Live.Brand.Shared,
    only: [email_signature_preview: 1, client_proposal_preview: 1, brand_logo_preview: 1]

  @default_client_proposal_params %{
    client_proposal: %{
      title: "Welcome",
      booking_panel_title: "Here's how to officially book your photo session:",
      message:
        "<p>Let's get your shoot booked!</p><p><br></p><p>We are so excited to work with you!</p><p><br></p><p>Your session will not be considered officially...</p><p><br></p><p>We can't wait to capture this time for you!</p>"
    }
  }

  @impl true
  def mount(_params, _session, socket) do
    socket |> assign(:page_title, "Settings") |> assign_organization() |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.settings_nav socket={@socket} live_action={@live_action} current_user={@current_user} intro_id="intro_settings_brand">
      <div class="flex flex-col justify-between flex-1 flex-grow-0 mt-5 sm:flex-row">
        <div>
          <h1 class="text-2xl font-bold">Brand</h1>

          <p class="max-w-2xl my-2 text-base-250">
            Edit the look and feel of your business. Any change here will apply across your Picsello experience including, your Public Profile, Marketing emails, and Gallery.
          </p>
        </div>
      </div>

      <hr class="my-4 sm:my-10" />

      <.card title="Upload a logo">
        <div class={"grid sm:grid-cols-2 gap-6 sm:gap-12 sm:pr-10 sm:pb-10"}>
          <div class="mt-4">
            <div class="text-base-250">
              Showcase your brand—if you don’t have a logo, no worries, we will display a default one.
            </div>
            <button phx-click="add-update-logo" class="hidden mt-6 sm:block btn-primary intro-signature">Add or update logo</button>
          </div>
          <div {testid("logo-preview")} class="flex flex-col">
            <.brand_logo_preview organization={@organization} user={@current_user} />
            <button phx-click="add-update-logo" class="self-end block mt-20 sm:hidden btn-primary">Add or update logo</button>
          </div>
        </div>
      </.card>

      <.card title="Change your email signature">
        <div class={"grid sm:grid-cols-2 gap-6 sm:gap-12 sm:pr-10"}>
          <div class="mt-4">
            <div class="text-base-250">
              Here’s the email signature that we’ve generated for you that will be included on all <.live_link class="link" to={Routes.inbox_path(@socket, :index)}>Inbox</.live_link> emails.
              To change your info, update your
              <.live_link class="link" to={Routes.user_settings_path(@socket, :edit)}>business name</.live_link>
               and modify your <.live_link class="link" to={Routes.user_settings_path(@socket, :edit)}>phone number</.live_link>.
            </div>
            <button phx-click="edit-signature" class="hidden mt-6 sm:block btn-primary intro-signature">Change signature</button>
          </div>
          <div {testid("signature-preview")} class="flex flex-col">
            <.email_signature_preview organization={@organization} user={@current_user} />
            <button phx-click="edit-signature" class="self-end block mt-12 sm:hidden btn-primary">Change your email signature</button>
          </div>
        </div>
      </.card>

      <.card title="Update your client proposal introduction">
        <div class={"grid sm:grid-cols-2 gap-6 sm:gap-12 sm:pr-10 sm:pb-10"}>
          <div class="mt-4">
            <div class="text-base-250">
              Customize how you’d like to welcome your clients as they view your proposal or client booking portal as they start booking a session
            </div>
            <button phx-click="customize-portal" class="hidden mt-6 sm:block btn-primary intro-signature">Customize</button>
          </div>
          <div {testid("portal-preview")} class="flex flex-col">
            <.client_proposal_preview organization={@organization} user={@current_user} default_client_proposal_params={@default_client_proposal_params}/>
            <button phx-click="customize-portal" class="self-end block mt-12 sm:hidden btn-primary">Customize</button>
          </div>
        </div>
      </.card>
    </.settings_nav>
    """
  end

  @impl true
  def handle_event("add-update-logo", %{}, %{assigns: %{organization: organization}} = socket) do
    socket
    |> PicselloWeb.Brand.BrandLogoComponent.open(organization)
    |> noreply()
  end

  @impl true
  def handle_event("edit-signature", %{}, %{assigns: %{organization: organization}} = socket),
    do:
      socket
      |> PicselloWeb.Live.Brand.EditSignatureComponent.open(organization)
      |> noreply()

  @impl true
  def handle_event("customize-portal", %{}, %{assigns: %{organization: organization}} = socket)
    do
      socket
      |> PicselloWeb.Live.Brand.CustomizeClientProposalComponent.open(organization)
      |> noreply()
    end

  @impl true
  def handle_event("intro_js" = event, params, socket),
    do: PicselloWeb.LiveHelpers.handle_event(event, params, socket)

  @impl true
  def handle_info({:update, organization, flash_message}, socket) do
    socket
    |> assign_organization(organization)
    |> put_flash(:success, flash_message)
    |> noreply()
  end

  @impl true
  def handle_info({:image_ready, image_field, organization}, socket) do
    consume_uploaded_entries(socket, image_field, fn _, _ -> ok(nil) end)

    socket |> assign_organization(organization) |> noreply()
  end

  defp assign_organization(%{assigns: %{current_user: current_user}} = socket) do
    socket |> assign_organization(current_user.organization)
  end

  defp assign_organization(socket, organization) do
    socket
    |> assign(:organization, organization)
    |> assign(
      :default_client_proposal_params,
      put_in(
        @default_client_proposal_params,
        [:client_proposal, :contact_button],
        "Message #{organization.name}"
      )
    )
  end
end
