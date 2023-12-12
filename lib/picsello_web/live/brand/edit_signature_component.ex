defmodule PicselloWeb.Live.Brand.EditSignatureComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Organization, Repo}
  import PicselloWeb.Live.Brand.Shared, only: [email_signature_preview: 1]
  import PicselloWeb.Shared.Quill, only: [quill_input: 1]

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_changeset()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div class="flex flex-col modal">
        <div class="flex items-start justify-between flex-shrink-0">
          <h1 class="mb-4 text-3xl font-bold">
            Edit email signature
          </h1>

          <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
            <.icon name="close-x" class="w-3 h-3 stroke-current stroke-2 sm:stroke-1 sm:w-6 sm:h-6"/>
          </button>
        </div>

        <.form for={@changeset} :let={f} phx-change="validate" phx-submit="save" phx-target={@myself}>
          <%= for e <- inputs_for(f, :email_signature) do %>
            <div class="grid mt-4 grid-cols-1 sm:grid-cols-5 gap-5 sm:gap-12 mb-6">

              <div class="col-span-3">
                <div>
                  <div class="input-label mb-4">Extra content</div>
                  <.quill_input f={e} html_field={:content} placeholder="Start typing…" />
                </div>
                <div class="grid grid-cols-1 sm:grid-cols-2">
                  <label class="flex my-4 cursor-pointer">
                    <%= checkbox(e, :show_business_name, class: "w-6 h-6 mt-1 checkbox") %>
                    <p class="ml-3 text-base-250"><span class="font-bold text-base-300">Show your business name?</span> <br />(Edit in account settings)</p>
                  </label>
                  <%= if @current_user.onboarding.phone do %>
                    <label class="flex my-4 cursor-pointer">
                      <%= checkbox(e, :show_phone, class: "w-6 h-6 mt-1 checkbox") %>
                      <p class="ml-3 text-base-250"><span class="font-bold text-base-300">Show your phone number?</span> <br />(Edit in account settings)</p>
                    </label>
                  <% else %>
                    <p class="text-base-250 my-4 italic">Add your phone number in account settings to enable/disable in your signature.</p>
                  <% end %>
                </div>
              </div>

              <div class="col-span-2">
                <.email_signature_preview organization={current_organization(@changeset)} user={@current_user} />
              </div>
            </div>
          <% end %>


          <PicselloWeb.LiveModal.footer disabled={!@changeset.valid?} />
        </.form>
      </div>
    """
  end

  @impl true
  def handle_event("validate", %{"organization" => params}, socket) do
    socket |> assign_changeset(:validate, params) |> noreply()
  end

  @impl true
  def handle_event(
        "save",
        %{"organization" => params},
        socket
      ) do
    case socket |> build_changeset(params) |> Repo.update() do
      {:ok, organization} ->
        send(socket.parent_pid, {:update, organization, "Email signature saved"})
        socket |> close_modal() |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  defp build_changeset(
         %{assigns: %{organization: organization}},
         params
       ) do
    Organization.email_signature_changeset(organization, params)
  end

  defp assign_changeset(socket, action \\ nil, params \\ %{})

  defp assign_changeset(socket, :validate, params) do
    changeset =
      socket
      |> build_changeset(params)
      |> Map.put(:action, :validate)

    assign(socket, changeset: changeset)
  end

  defp assign_changeset(socket, action, params) do
    changeset = build_changeset(socket, params) |> Map.put(:action, action)

    assign(socket, changeset: changeset)
  end

  defp current_organization(changeset), do: Ecto.Changeset.apply_changes(changeset)

  def open(%{assigns: %{current_user: current_user}} = socket, organization) do
    socket |> open_modal(__MODULE__, %{current_user: current_user, organization: organization})
  end
end
