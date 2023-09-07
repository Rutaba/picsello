defmodule PicselloWeb.Live.Admin.GlobalSettings do
  @moduledoc "update admin global settings"
  use PicselloWeb, live_view: [layout: false]

  alias Picsello.{AdminGlobalSetting, AdminGlobalSettings}
  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_changesets()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="p-8 bg-gray-100">
      <h1 class="text-4xl font-bold">Manage Global Settings</h1>
    </header>

    <div class="p-4">
      <div class="relative overflow-x-auto">
        <table class="w-full text-sm text-left text-gray-500 dark:text-gray-400">
          <thead class="text-xs text-gray-700 uppercase bg-gray-50 dark:bg-gray-700 dark:text-gray-400">
            <tr>
              <%= for value <- ["Slug", "Title", "Description", "value", "Status"] do %>
                <th scope="col" class="px-12 py-3">
                  <%= value%>
                </th>
              <% end %>
            </tr>
          </thead>
          <tbody>
            <%= for({changeset, i} <- @changesets) do %>
              <tr class="bg-white dark:bg-gray-800">
                <.form :let={f} for={changeset} class="contents" phx-change="save" id={"form-#{i}"}>
                  <%= hidden_input f, :index, value: i %>
                  <td class="px-12 py-4">
                    <%= input f, :slug, phx_debounce: 200, class: "w-36", disabled: true %>
                  </td>
                  <td class="px-12 py-4">
                    <%= input f, :title, phx_debounce: 200, class: "w-42" %>
                  </td>
                  <td class="px-12 py-4">
                    <%= input f, :description, phx_debounce: 200, class: "w-64" %>
                  </td>
                  <td class="px-12 py-4">
                    <%= input f, :value, phx_debounce: 200, class: "w-16" %>
                  </td>
                  <td class="px-12 py-4">
                    <%= select f, :status, [:active, :disabled, :archived], phx_debounce: 200, disabled: true %>
                  </td>
                </.form>
                </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event(
        "save",
        %{"admin_global_setting" => %{"index" => index} = params},
        %{assigns: %{changesets: changesets}} = socket
      ) do
    {%{data: data}, _i} = Enum.at(changesets, String.to_integer(index))

    AdminGlobalSettings.update_setting!(data, params)

    socket
    |> assign_changesets()
    |> noreply()
  end

  defp assign_changesets(socket) do
    socket
    |> assign(
      changesets:
        AdminGlobalSettings.get_all_settings()
        |> Enum.sort_by(& &1.slug)
        |> Enum.map(&AdminGlobalSetting.changeset(&1))
        |> Enum.with_index()
    )
  end
end
