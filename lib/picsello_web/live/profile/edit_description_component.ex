defmodule PicselloWeb.Live.Profile.EditDescriptionComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Profiles}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_organization()
    |> assign_changeset()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal !max-w-md ">
      <h1 class="text-3xl font-bold">Edit Description</h1>

      <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>

        <%= for p <- inputs_for(f, :profile) do %>
          <div id="editor-wrapper" phx-hook="Quill" phx-update="ignore" class="mt-4" data-placeholder="Start typing…" data-html-field-name={input_name(p, :description)}>
            <div id="toolbar" class="bg-blue-planning-100 text-blue-planning-300">
              <button class="ql-bold"></button>
              <button class="ql-italic"></button>
              <button class="ql-underline"></button>
              <button class="ql-list" value="bullet"></button>
              <button class="ql-list" value="ordered"></button>
              <button class="ql-link"></button>
            </div>
            <div id="editor" style="min-height: 4rem;"> </div>
            <%= hidden_input p, :description, phx_debounce: "500" %>
          </div>
        <% end %>

        <PicselloWeb.LiveModal.footer>
          <button class="btn-primary" title="save" type="submit" phx-disable-with="Save">
            Save
          </button>

          <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
            Cancel
          </button>
        </PicselloWeb.LiveModal.footer>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"organization" => params}, socket) do
    socket |> assign_changeset(params) |> noreply()
  end

  @impl true
  def handle_event(
        "save",
        %{"organization" => params},
        %{assigns: %{organization: organization}} = socket
      ) do
    case Profiles.update_organization_profile(organization, params) do
      {:ok, organization} ->
        send(socket.parent_pid, {:update, organization})
        socket |> close_modal() |> noreply()

      {:error, _} ->
        socket |> noreply()
    end
  end

  def open(%{assigns: assigns} = socket, opts \\ %{}),
    do:
      open_modal(
        socket,
        __MODULE__,
        %{
          assigns: Enum.into(opts, Map.take(assigns, [:current_user]))
        }
      )

  defp assign_changeset(
         %{assigns: %{organization: organization}} = socket,
         params \\ %{},
         action \\ :validate
       ) do
    changeset =
      organization
      |> Profiles.edit_organization_profile_changeset(params)
      |> Map.put(:action, action)

    assign(socket, changeset: changeset)
  end

  defp assign_organization(%{assigns: %{current_user: current_user}} = socket) do
    organization = Profiles.find_organization_by(user: current_user)
    socket |> assign(:organization, organization)
  end
end
