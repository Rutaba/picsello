defmodule PicselloWeb.Live.Admin.User.ContactUpload do
  @moduledoc "Manage Uploading contacts for user"
  use PicselloWeb, live_view: [layout: false]

  alias Picsello.{Repo, Accounts, Client, Contacts}

  import PicselloWeb.LayoutView,
    only: [
      flash: 1
    ]

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:uploaded_files, [])
    |> allow_upload(:contact_csv, accept: ~w(.csv), max_entries: 1)
    |> ok()
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    user = Accounts.get_user!(id)
    clients = Contacts.find_all_by(user: user)

    socket
    |> assign(:user, user)
    |> assign(:clients, clients)
    |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= flash(@flash) %>
    <header class="p-8 bg-gray-100">
      <h1 class="text-4xl font-bold">Upload contacts</h1>
    </header>
    <div class="p-8">
      <div class="grid grid-cols-2 gap-12">
        <div class="p-4 border rounded-lg">
          <h3 class="text-2xl font-bold mb-4">Current user:</h3>
          <h3 class="text-xl font-bold"><%= @user.name %></h3>
          <h4><%= @user.email %></h4>
          <h4>Organization id: <%= @user.organization_id %></h4>
        </div>
        <div class="p-4 border rounded-lg">
          <h4 class="font-bold text-red-sales-300">NOTE: Please make a copy of the <a class="underline" href="https://docs.google.com/spreadsheets/d/1vAzfbjUviI3c2G_uXU29EdfEDtufa5r59E2ESho4eOA/edit?usp=sharing" target="_blank" rel="noreferre">Google Sheet template</a>, fill it out with the exact columns, and download to CSV before uploading</h4>
          <h3 class="text-2xl font-bold mb-4">Upload file</h3>
          <form id="upload-form" phx-submit="save" phx-change="validate">
            <%= live_file_input @uploads.contact_csv, class: "" %>
            <button class="btn-primary" type="submit">Upload</button>
          </form>
        </div>
      </div>
      <%= if Enum.empty? @clients do %>
        <div class="mt-5">
        User doesn't have any clients
        </div>
      <% end %>
      <table class="flex flex-row flex-no-wrap w-full mt-5 mb-32 responsive-table sm:bg-white sm:mb-5">
        <thead class="text-white">
          <%= for _client <- @clients do %>
            <tr class="flex flex-col mb-2 overflow-hidden rounded-l-lg flex-no wrap sm:table-row sm:mb-0">
              <th class="p-3 text-left uppercase bg-base-300">Name</th>
              <th class="p-3 text-left uppercase bg-base-300">Email</th>
            </tr>
          <% end %>
        </thead>
        <tbody class="flex-1 sm:flex-none">
            <%= for client <- @clients do %>
              <tr class="flex flex-col mb-2 flex-no wrap sm:table-row sm:mb-0">
                <td class="p-3 truncate border border-grey-light sm:border-none"><%= client.name || "-" %></td>
                <td class="p-3 truncate border border-grey-light sm:border-none"><%= client.email || "-" %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
    </div>
    """
  end

  @impl true
  def handle_event(
        "validate",
        _params,
        socket
      ) do
    socket |> noreply()
  end

  @impl true
  def handle_event(
        "save",
        _params,
        %{assigns: %{user: %{organization_id: organization_id} = user}} = socket
      ) do
    case consume_uploaded_entries(socket, :contact_csv, fn %{path: path}, _entry ->
           handle_upload(path, organization_id) |> handle_response()
         end) do
      [] ->
        socket
        |> put_flash(:error, "No file selected")

      [:done] ->
        clients = Contacts.find_all_by(user: user)

        socket
        |> put_flash(:info, "Contacts uploaded successfully")
        |> assign(:clients, clients)

      [error: email] ->
        socket
        |> put_flash(
          :error,
          "There was an error uploading the contacts, duplicate address likely: #{email}"
        )
    end
    |> noreply()
  end

  defp handle_response({:ok, _}) do
    {:ok, :done}
  end

  defp handle_response({:error, _failed_operation, failed_value, _changes_so_far}) do
    {:postpone, {:error, failed_value.changes.email}}
  end

  defp handle_upload(path, organization_id) do
    path
    |> File.stream!()
    |> CSV.decode!(headers: true)
    |> Enum.with_index()
    |> Enum.reduce(Ecto.Multi.new(), fn {client, index}, multi ->
      client_changeset =
        client
        |> Map.put("organization_id", organization_id)
        |> Client.create_contact_changeset()

      Ecto.Multi.insert(multi, index, client_changeset)
    end)
    |> Repo.transaction()
  end
end
