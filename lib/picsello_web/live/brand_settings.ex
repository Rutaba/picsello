defmodule PicselloWeb.Live.BrandSettings do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.User.Settings, only: [settings_nav: 1, card: 1]
  import PicselloWeb.Live.Brand.Shared, only: [email_signature_preview: 1]

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

          <p class="max-w-2xl my-2">
            Edit the look and feel of your business. Any change here will apply across your Picsello experience including, your Public Profile, Marketing emails, and Gallery.
          </p>
        </div>
      </div>

      <hr class="my-4 sm:my-10" />

      <.card title="Change your email signature">
        <div class={"grid sm:grid-cols-2 gap-6 sm:gap-12 sm:pr-10 sm:pb-10"}>
          <div class="mt-4">
            <div>
              Here’s the email signature that we’ve generated for you that will be included on all <.live_link class="link" to={Routes.inbox_path(@socket, :index)}>Inbox</.live_link> emails. To change your info, you’ll have to upload a logo <.live_link class="link" to={Routes.profile_settings_path(@socket, :edit)}>here</.live_link>, update your <.live_link class="link" to={Routes.user_settings_path(@socket, :edit)}>business name</.live_link> and modify your phone number.
            </div>
            <button phx-click="edit-signature" class="hidden mt-6 sm:block btn-primary intro-signature">Change signature</button>
          </div>
          <div {testid("signature-preview")} class="flex flex-col">
            <.email_signature_preview organization={@organization} user={@current_user} />
            <button phx-click="edit-signature" class="self-end block mt-12 sm:hidden btn-primary">Change signature</button>
          </div>
        </div>
      </.card>
    </.settings_nav>
    """
  end

  @impl true
  def handle_event("edit-signature", %{}, %{assigns: %{organization: organization}} = socket),
    do:
      socket
      |> PicselloWeb.Live.Brand.EditSignatureComponent.open(organization)
      |> noreply()

  @impl true
  def handle_event("intro_js" = event, params, socket),
    do: PicselloWeb.LiveHelpers.handle_event(event, params, socket)

  @impl true
  def handle_info({:update, organization}, socket) do
    socket
    |> assign_organization(organization)
    |> put_flash(:success, "Email signature saved")
    |> noreply()
  end

  defp assign_organization(%{assigns: %{current_user: current_user}} = socket) do
    socket |> assign_organization(current_user.organization)
  end

  defp assign_organization(socket, organization) do
    socket |> assign(:organization, organization)
  end
end
