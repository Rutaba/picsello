defmodule PicselloWeb.Live.Contacts do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.User.Settings, only: [settings_nav: 1]
  alias Picsello.Contacts

  @impl true
  def mount(_params, _session, %{assigns: %{current_user: user}} = socket) do
    socket |> assign_contacts() |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.settings_nav socket={@socket} live_action={@live_action}>
      <div class="flex flex-col justify-between flex-1 mt-5 flex-grow-0 sm:flex-row">
        <div>
          <h1 class="text-2xl font-bold">Manage your contacts</h1>

          <p class="max-w-2xl my-2">
            You have <%= ngettext "1 contact", "%{count} contacts", length(@contacts) %>
          </p>
        </div>

        <div class="fixed bottom-0 left-0 right-0 z-20 flex flex-shrink-0 w-full p-6 mt-auto bg-white sm:mt-0 sm:bottom-auto sm:static sm:items-start sm:w-auto">
          <button type="button" phx-click="add-contact" class="w-full px-8 text-center btn-primary">Add contact</button>
        </div>
      </div>

      <hr class="my-4 sm:my-10" />

      <table class="responsive-table w-full flex flex-row flex-no-wrap sm:bg-white my-5">
        <thead class="text-white">
          <%= for contact <- @contacts do %>
            <tr class="flex flex-col flex-no wrap rounded-l-lg overflow-hidden sm:table-row mb-2 sm:mb-0">
              <th class="bg-base-300 p-3 text-left uppercase">Email</th>
              <th class="bg-base-300 p-3 text-left uppercase">Name</th>
              <th class="bg-base-300 p-3 text-left uppercase" width="110px">Actions</th>
            </tr>
          <% end %>
        </thead>
        <tbody class="flex-1 sm:flex-none">
          <%= for contact <- @contacts do %>
            <tr class="flex flex-col flex-no wrap sm:table-row mb-2 sm:mb-0">
              <td class="border-grey-light border sm:border-none p-3 truncate"><%= contact.email %></td>
              <td class="border-grey-light border sm:border-none p-3 truncate"><%= contact.name || "-" %></td>
              <td class="border-grey-light border sm:border-none p-3 relative">
                &nbsp;
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>

    </.settings_nav>
    """
  end

  defp assign_contacts(%{assigns: %{current_user: current_user}} = socket) do
    contacts = Contacts.find_all_by(user: current_user)

    socket |> assign(:contacts, contacts)
  end
end
