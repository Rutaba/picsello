defmodule PicselloWeb.Live.Contacts do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.User.Settings, only: [settings_nav: 1]
  alias Picsello.Contacts

  @impl true
  def mount(_params, _session, socket) do
    socket |> assign_contacts() |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.settings_nav socket={@socket} live_action={@live_action} current_user={@current_user}>
      <div class="flex flex-col justify-between flex-1 mt-5 flex-grow-0 sm:flex-row">
        <div>
          <h1 class="text-2xl font-bold">Contacts <.intro_hint content="Adding a contact will save their information without creating a lead - this is a great option if a client isn’t quite interested in a job yet, but you want to keep track of their contact info." /></h1>

          <p class="max-w-2xl my-2">
            Manage your <%= ngettext "1 contact", "%{count} contacts", length(@contacts) %>
          </p>
        </div>

        <div class="fixed bottom-0 left-0 right-0 z-20 flex flex-shrink-0 w-full p-6 mt-auto bg-white sm:mt-0 sm:bottom-auto sm:static sm:items-start sm:w-auto">
          <button type="button" phx-click="add-contact" class="w-full px-8 text-center btn-primary">Add contact </button>
        </div>
      </div>

      <hr class="my-4 sm:my-10" />

      <table class="responsive-table w-full flex flex-row flex-no-wrap sm:bg-white mt-5 mb-32 sm:mb-5">
        <thead class="text-white">
          <%= for _contact <- @contacts do %>
            <tr class="flex flex-col flex-no wrap rounded-l-lg overflow-hidden sm:table-row mb-2 sm:mb-0">
              <th class="bg-base-300 p-3 text-left uppercase">Name</th>
              <th class="bg-base-300 p-3 text-left uppercase">Email</th>
              <th class="bg-base-300 p-3 text-left uppercase" width="110px">Actions</th>
            </tr>
          <% end %>
        </thead>
        <tbody class="flex-1 sm:flex-none">
          <%= for contact <- @contacts do %>
            <tr class="flex flex-col flex-no wrap sm:table-row mb-2 sm:mb-0">
              <td class="border-grey-light border sm:border-none p-3 truncate"><%= contact.name || "-" %></td>
              <td class="border-grey-light border sm:border-none p-3 truncate"><%= contact.email || "-" %></td>
              <td class="border-grey-light border sm:border-none p-3 relative">
                &nbsp;
                <div class="absolute top-3 left-3 sm:left-8" data-offset="0" data-placement="bottom-end" phx-hook="Select" id={"manage-contact-#{contact.id}"}>
                  <button title="Manage" type="button" class="flex flex-shrink-0 p-1 text-2xl font-bold bg-white border rounded border-blue-planning-300 text-blue-planning-300">
                    <.icon name="hellip" class="w-4 h-1 m-1 fill-current open-icon text-blue-planning-300" />

                    <.icon name="close-x" class="hidden w-3 h-3 mx-1.5 stroke-current close-icon stroke-2 text-blue-planning-300" />
                  </button>

                  <div class="z-10 flex flex-col w-40 hidden bg-white border rounded-lg shadow-lg popover-content">
                    <button title="Edit" type="button" phx-click="edit-contact" phx-value-id={contact.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
                      <.icon name="pencil" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                      Edit
                    </button>
                    <button title="Create a lead" type="button" phx-click="create-lead" phx-value-id={contact.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
                      <.icon name="three-people" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                      Create a lead
                    </button>
                  </div>
                </div>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>

    </.settings_nav>
    """
  end

  @impl true
  def handle_event("add-contact", %{}, socket),
    do:
      socket
      |> PicselloWeb.Live.Contacts.ContactFormComponent.open()
      |> noreply()

  @impl true
  def handle_event(
        "edit-contact",
        %{"id" => id},
        %{assigns: %{contacts: contacts}} = socket
      ) do
    {id, _} = Integer.parse(id)
    contact = contacts |> Enum.find(&(&1.id == id))

    socket
    |> PicselloWeb.Live.Contacts.ContactFormComponent.open(contact)
    |> noreply()
  end

  @impl true
  def handle_event(
        "create-lead",
        %{"id" => id},
        %{assigns: %{contacts: contacts}} = socket
      ) do
    {id, _} = Integer.parse(id)
    contact = contacts |> Enum.find(&(&1.id == id))

    assigns = %{
      current_user: socket.assigns.current_user,
      email: contact.email,
      phone: contact.phone,
      name: contact.name
    }

    socket
    |> open_modal(PicselloWeb.JobLive.NewComponent, assigns)
    |> noreply()
  end

  def handle_event("intro_js" = event, params, socket),
    do: PicselloWeb.LiveHelpers.handle_event(event, params, socket)

  defp assign_contacts(%{assigns: %{current_user: current_user}} = socket) do
    contacts = Contacts.find_all_by(user: current_user)

    socket |> assign(:contacts, contacts)
  end

  @impl true
  def handle_info({:update, _contact}, socket) do
    socket
    |> assign_contacts()
    |> put_flash(:success, "Contact saved")
    |> noreply()
  end
end
