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
        <table class="w-full text-left text-gray-500 dark:text-gray-400">
          <thead class="text-xs text-gray-700 uppercase bg-gray-50 dark:bg-gray-700 dark:text-gray-400">
            <tr>
              <%= for value <- ["Setting", "value", "Status"] do %>
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
                  <%= hidden_input f, :slug %>
                  <%= hidden_input f, :title %>
                  <%= hidden_input f, :description %>
                  <td class="px-12 py-4">
                    <div class="uppercase font-bold"> <%= input_value(f, :title) %> </div>
                    <div class="text-sm text-sm"> <%= input_value(f, :description) %> </div>
                  </td>
                  <td class="px-12 py-4">
                    <%= input f, :value, phx_debounce: 200, class: "w-2/5" %>
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
    value = params["value"]

    if value && String.length(value) > 0 do
      AdminGlobalSettings.update_setting!(data, params)
    end

    socket
    |> assign_changesets()
    |> noreply()
  end

  defp assign_changesets(socket) do
    socket
    |> assign(
      changesets:
        AdminGlobalSettings.get_all_settings()
        |> Enum.map(&AdminGlobalSetting.changeset(&1))
        |> Enum.with_index()
    )
  end
end
