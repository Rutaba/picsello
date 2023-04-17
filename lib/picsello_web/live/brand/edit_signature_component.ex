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
            <div class="grid mt-4 grid-cols-1 sm:grid-cols-3 gap-5 sm:gap-12 mb-6">

              <div class="col-span-2">
                <div class="input-label">Extra content</div>

                <.quill_input f={e} html_field={:content} placeholder="Start typing…" />
              </div>
              <label class="flex flex-col justify-center">
                <div class="input-label">Show your phone number?</div>
                <div class="mt-2 flex items-center">
                  <%= checkbox(e, :show_phone, class: "peer hidden") %>

                  <div class="hidden peer-checked:flex items-center">
                    <div class="rounded-full bg-blue-planning-300 border border-base-100 w-16 p-1 flex justify-end mr-4">
                      <div class="rounded-full h-7 w-7 bg-base-100"></div>
                    </div>
                  </div>

                  <div class="flex peer-checked:hidden items-center">
                    <div class="rounded-full w-16 p-1 flex mr-4 border border-blue-planning-300">
                      <div class="rounded-full h-7 w-7 bg-blue-planning-300"></div>
                    </div>
                  </div>
                </div>
              </label>
            </div>
          <% end %>

          <.email_signature_preview organization={current_organization(@changeset)} user={@current_user} />

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
        send(socket.parent_pid, {:update, organization})
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
