defmodule PicselloWeb.Live.Contacts.ContactFormComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.Contacts

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
            <%= if @contact, do: "Edit contact", else: "Add contact" %>
          </h1>

          <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
            <.icon name="close-x" class="w-3 h-3 stroke-current stroke-2 sm:stroke-1 sm:w-6 sm:h-6"/>
          </button>
        </div>

        <.form for={@changeset} let={f} phx-change="validate" phx-submit="save" phx-target={@myself}>
          <div class="px-1.5 grid grid-cols-1 sm:grid-cols-2 gap-5">
            <%= labeled_input f, :name, placeholder: "Enter first and last name…", phx_debounce: "500" %>
            <%= labeled_input f, :email, placeholder: "Enter email…", phx_debounce: "500" %>
            <%= labeled_input f, :phone, type: :telephone_input, placeholder: "Enter phone number…", phx_hook: "Phone", phx_debounce: "500" %>
          </div>

          <PicselloWeb.LiveModal.footer disabled={!@changeset.valid?} />
        </.form>
      </div>
    """
  end

  @impl true
  def handle_event("validate", %{"client" => params}, socket) do
    socket |> assign_changeset(:validate, params) |> noreply()
  end

  @impl true
  def handle_event(
        "save",
        %{"client" => params},
        socket
      ) do
    case save_contact(params, socket) do
      {:ok, contact} ->
        send(socket.parent_pid, {:update, contact})
        socket |> close_modal() |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  defp save_contact(params, %{assigns: %{current_user: current_user, contact: nil}}) do
    Contacts.save_new_contact(params, current_user.organization_id)
  end

  defp save_contact(params, %{assigns: %{contact: contact}}) do
    Contacts.save_contact(contact, params)
  end

  defp build_changeset(
         %{assigns: %{current_user: current_user, contact: nil}},
         params
       ) do
    Contacts.new_contact_changeset(params, current_user.organization_id)
  end

  defp build_changeset(%{assigns: %{contact: contact}}, params) do
    Contacts.edit_contact_changeset(contact, params)
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

  def open(%{assigns: %{current_user: current_user}} = socket, contact \\ nil) do
    socket |> open_modal(__MODULE__, %{current_user: current_user, contact: contact})
  end
end
