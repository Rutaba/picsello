defmodule PicselloWeb.Live.ClientLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Repo, Client, Clients, ClientTag}

  import PicselloWeb.GalleryLive.Index, only: [update_gallery_listing: 1]
  import PicselloWeb.GalleryLive.Shared, only: [add_message_and_notify: 2]

  alias PicselloWeb.JobLive.{NewComponent, ImportWizard, Shared}

  alias PicselloWeb.{
    ConfirmationComponent,
    SuccessComponent,
    Live.ClientLive.ClientFormComponent,
    GalleryLive.CreateComponent
  }

  defmodule Pagination do
    @moduledoc false
    defstruct first_index: 1,
              last_index: 12,
              total_count: 0,
              limit: 12,
              offset: 0,
              after: nil,
              before: nil
  end

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_new(:pagination, fn -> %Pagination{} end)
    |> assign_clients()
    |> ok()
  end

  @impl true
  def handle_event(
        "close-tags",
        %{"client-id" => _client_id},
        socket
      ) do
    socket
    |> assign(
      :tags_changeset,
      tag_default_changeset(%{})
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "add-tags",
        %{"client-id" => client_id},
        socket
      ) do
    client_id = String.to_integer(client_id)

    socket
    |> assign(
      :tags_changeset,
      ClientTag.create_changeset(%{
        client_id: client_id
      })
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "delete-tag",
        %{"client_id" => client_id, "tag" => tag},
        %{assigns: %{clients: clients}} = socket
      ) do
    client_id = to_integer(client_id)
    Clients.delete_tag(client_id, tag)

    # update clients tags in assigns without fetching from the db
    client_index = clients |> Enum.find_index(&(&1.id == client_id))
    client = clients |> Enum.at(client_index)
    tags = client |> Map.get(:tags) |> Enum.filter(&(&1.name != tag))

    socket
    |> assign(:clients, List.replace_at(clients, client_index, Map.replace(client, :tags, tags)))
    |> assign(:tags_changeset, tag_default_changeset(%{}))
    |> noreply()
  end

  @impl true
  def handle_event(
        "delete-tag",
        %{"client_id" => client_id, "tag" => tag},
        %{assigns: %{client: client}} = socket
      ) do
    client_id = to_integer(client_id)
    Clients.delete_tag(client_id, tag)

    # update clients tags in assigns without fetching from the db
    tags = client |> Map.get(:tags) |> Enum.filter(&(&1.name != tag))

    socket
    |> assign(:client, Map.replace(client, :tags, tags))
    |> assign(:tags_changeset, tag_default_changeset(%{}))
    |> noreply()
  end

  @impl true
  def handle_event(
        "save-tags",
        %{
          "key" => "Enter",
          "client_id" => client_id,
          "value" => tags
        },
        %{assigns: %{clients: clients}} = socket
      ) do
    new_tags = String.split(tags, ",", trim: true)
    client_id = to_integer(client_id)
    client_index = clients |> Enum.find_index(&(&1.id == client_id))
    client = clients |> Enum.at(client_index)

    save_tags(client_id, new_tags, client)

    clients =
      List.replace_at(
        clients,
        client_index,
        Map.replace(client, :tags, Clients.get_client_tags(client_id))
      )

    socket
    |> assign(:tags_changeset, tag_default_changeset(%{}))
    |> assign(:clients, clients)
    |> noreply()
  end

  @impl true
  def handle_event(
        "save-tags",
        %{
          "key" => "Enter",
          "client_id" => client_id,
          "value" => tags
        },
        %{assigns: %{client: client}} = socket
      ) do
    new_tags = String.split(tags, ",", trim: true)
    client_id = to_integer(client_id)

    save_tags(client_id, new_tags, client)

    socket
    |> assign(:tags_changeset, tag_default_changeset(%{}))
    |> assign(:client, Map.replace(client, :tags, Clients.get_client_tags(client_id)))
    |> noreply()
  end

  @impl true
  def handle_event("save-tags", _value, socket), do: noreply(socket)

  @impl true
  def handle_event(
        "confirm-archive",
        %{"id" => id},
        %{assigns: %{clients: clients}} = socket
      ) do
    {client_id, _} = Integer.parse(id)
    client = clients |> Enum.find(&(&1.id == client_id))
    open_confirmation_component(socket, client)
  end

  @impl true
  def handle_event(
        "confirm-archive",
        %{"id" => _id},
        %{assigns: %{client: client}} = socket
      ) do
    open_confirmation_component(socket, client)
  end

  @impl true
  def handle_event("intro_js" = event, params, socket),
    do: PicselloWeb.LiveHelpers.handle_event(event, params, socket)

  @impl true
  def handle_event(
        "page",
        %{"direction" => direction},
        socket
      ) do
    update_fn =
      case direction do
        "back" -> &%{&1 | first_index: &1.first_index - &1.limit, offset: &1.offset - &1.limit}
        "forth" -> &%{&1 | first_index: &1.first_index + &1.limit, offset: &1.offset + &1.limit}
      end

    socket
    |> update(:pagination, update_fn)
    |> then(fn socket ->
      socket
      |> fetch_clients()
    end)
    |> noreply()
  end

  @impl true
  def handle_event(
        "page",
        %{"pagination" => %{"limit" => limit}},
        socket
      ) do
    limit = String.to_integer(limit)

    socket
    |> assign(:pagination, %Pagination{limit: limit, last_index: limit})
    |> then(fn socket ->
      socket
      |> fetch_clients()
    end)
    |> noreply()
  end

  @impl true
  def handle_event("page", %{}, socket), do: socket |> noreply()

  @impl true
  def handle_event(
        "search",
        %{"search_phrase" => search_phrase},
        %{assigns: %{pagination: pagination}} = socket
      ) do
    search_phrase = String.trim(search_phrase)

    search_phrase =
      if String.length(search_phrase) > 0, do: String.downcase(search_phrase), else: nil

    socket
    |> assign(search_phrase: search_phrase)
    |> assign(:pagination, reset_pagination(pagination))
    |> then(fn socket ->
      socket
      |> fetch_clients()
    end)
    |> noreply()
  end

  @impl true
  def handle_event("clear-search", _, %{assigns: %{pagination: pagination}} = socket) do
    socket
    |> assign(:search_phrase, nil)
    |> assign(:pagination, reset_pagination(pagination))
    |> then(fn socket ->
      socket
      |> fetch_clients()
    end)
    |> noreply()
  end

  @impl true
  def handle_event(
        "apply-filter-status",
        %{"option" => status},
        %{assigns: %{pagination: pagination}} = socket
      ) do
    socket
    |> assign(:job_status, status)
    |> assign(:pagination, reset_pagination(pagination))
    |> then(fn socket ->
      socket
      |> fetch_clients()
    end)
    |> noreply()
  end

  @impl true
  def handle_event(
        "apply-filter-type",
        %{"option" => type},
        %{assigns: %{pagination: pagination}} = socket
      ) do
    socket
    |> assign(:job_type, type)
    |> assign(:pagination, reset_pagination(pagination))
    |> then(fn socket ->
      socket
      |> fetch_clients()
    end)
    |> noreply()
  end

  @impl true
  def handle_event(
        "apply-filter-sort_by",
        %{"option" => sort_by},
        %{assigns: %{pagination: pagination}} = socket
      ) do
    socket
    |> assign(:sort_by, sort_by)
    |> assign(:sort_col, Enum.find(sort_options(), fn op -> op.id == sort_by end).column)
    |> assign(:sort_direction, Enum.find(sort_options(), fn op -> op.id == sort_by end).direction)
    |> assign(:pagination, reset_pagination(pagination))
    |> then(fn socket ->
      socket
      |> fetch_clients()
    end)
    |> noreply()
  end

  @impl true
  def handle_event(
        "sort_direction",
        _,
        %{assigns: %{desc: desc, pagination: pagination}} = socket
      ) do
    socket
    |> assign(:desc, !desc)
    |> assign(:pagination, reset_pagination(pagination))
    |> then(fn socket ->
      socket
      |> fetch_clients()
    end)
    |> noreply()
  end

  @impl true
  def handle_event("add-client", %{}, socket),
    do:
      socket
      |> ClientFormComponent.open()
      |> noreply()

  @impl true
  def handle_event(
        "edit-client",
        %{"id" => _id},
        %{assigns: %{client: client}} = socket
      ) do
    socket
    |> ClientFormComponent.open(client)
    |> noreply()
  end

  @impl true
  def handle_event(
        "edit-client",
        %{"id" => id},
        socket
      ) do
    {id, _} = Integer.parse(id)

    socket
    |> redirect(to: "/clients/#{id}")
    |> noreply()
  end

  @impl true
  def handle_event(
        "create-lead",
        %{"id" => id},
        %{assigns: %{clients: clients, current_user: current_user}} = socket
      ) do
    {id, _} = Integer.parse(id)
    client = clients |> Enum.find(&(&1.id == id))

    assigns = %{
      current_user: current_user,
      selected_client: client
    }

    socket
    |> open_modal(NewComponent, assigns)
    |> noreply()
  end

  @impl true
  def handle_event(
        "import-job",
        %{"id" => id},
        %{assigns: %{clients: clients, current_user: current_user}} = socket
      ) do
    {id, _} = Integer.parse(id)
    client = clients |> Enum.find(&(&1.id == id))

    assigns = %{
      current_user: current_user,
      selected_client: client,
      step: :job_details
    }

    socket
    |> open_modal(ImportWizard, assigns)
    |> noreply()
  end

  @impl true
  def handle_event(
        "import-job",
        %{"id" => _id},
        %{assigns: %{client: client, current_user: current_user}} = socket
      ) do
    assigns = %{
      current_user: current_user,
      selected_client: client,
      step: :job_details
    }

    socket
    |> open_modal(ImportWizard, assigns)
    |> noreply()
  end

  @impl true
  def handle_event(
        "create-gallery",
        %{"id" => id},
        %{assigns: %{clients: clients}} = socket
      ) do
    {id, _} = Integer.parse(id)
    client = clients |> Enum.find(&(&1.id == id))

    assigns = %{
      current_user: socket.assigns.current_user,
      selected_client: client
    }

    socket
    |> open_modal(CreateComponent, assigns)
    |> noreply()
  end

  def handle_info({:success_event, "view-gallery", %{gallery_id: gallery_id}}, socket) do
    socket
    |> push_redirect(to: Routes.gallery_photographer_index_path(socket, :index, gallery_id))
    |> noreply()
  end

  @impl true
  defdelegate handle_event(name, params, socket), to: Shared

  @impl true
  def handle_info({:update, _client}, socket) do
    socket
    |> assign_clients()
    |> put_flash(:success, "Client saved successfully")
    |> noreply()
  end

  @impl true
  def handle_info({:confirm_event, "archive_" <> id}, socket) do
    case Clients.archive_client(id) do
      {:ok, _client} ->
        socket
        |> close_modal()
        |> push_redirect(to: Routes.clients_path(socket, :index))
        |> put_flash(:success, "Client archived successfully")
        |> assign_clients()
        |> noreply()

      {:error, _} ->
        socket
        |> close_modal()
        |> put_flash(:success, "Error archiving client")
        |> push_redirect(to: Routes.clients_path(socket, :index))
        |> noreply()
    end
  end

  @impl true
  def handle_info({:gallery_created, %{gallery_id: gallery_id}}, socket) do
    socket
    |> SuccessComponent.open(%{
      title: "Gallery Created!",
      subtitle: "Hooray! Your gallery has been created. You're now ready to upload photos.",
      success_label: "View gallery",
      success_event: "view-gallery",
      close_label: "Close",
      payload: %{gallery_id: gallery_id}
    })
    |> update_gallery_listing()
    |> noreply()
  end

  @impl true
  def handle_info({:message_composed, message_changeset}, socket) do
    add_message_and_notify(socket, message_changeset)
  end

  @impl true
  defdelegate handle_info(message, socket), to: Shared

  def select_dropdown(assigns) do
    ~H"""
    <div id="select" class={"relative w-full mt-3 md:mt-0 md:ml-5"} data-offset-y="10" phx-hook="Select">
      <h1 class="font-extrabold text-sm"><%= @title %></h1>
      <div class="flex flex-row items-center">
          <%= String.capitalize(String.replace(@selected_option, "_", " ")) %>
          <.icon name="down" class="w-3 h-3 ml-auto lg:mr-2 mr-1 stroke-current stroke-2 open-icon" />
          <.icon name="up" class="hidden w-3 h-3 ml-auto lg:mr-2 mr-1 stroke-current stroke-2 close-icon" />
      </div>
      <ul class="absolute z-30 hidden md:w-32 w-full mt-2 bg-white toggle rounded-md popover-content border border-base-200">
        <%= for option <- @options_list do %>
          <li id={option.id} target-class="toggle-it" parent-class="toggle" toggle-type="selected-active" phx-hook="ToggleSiblings"
          class="flex items-center py-1.5 hover:bg-blue-planning-100 hover:rounded-md">
            <button id={option.id} class="album-select" phx-click={"apply-filter-#{@id}"} phx-value-option={option.id}><%= option.title %></button>
            <%= if option.id == @selected_option do %>
              <.icon name="tick" class="w-6 h-5 mr-1 toggle-it text-green" />
            <% end %>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  def tags(assigns) do
    ~H"""
      <div class="flex-wrap items-center sm:col-span-2 sm:flex gap-2 sm:gap-0">
        <%= if Enum.empty?(Clients.client_tags(@client)) do%>
            <p><%= "-" %></p>
        <% else %>
          <%= for tag <- Clients.client_tags(@client) do%>
            <span class="mb-2 inline-block mt-1 pb-1 text-s bg-gray-200 text-gray-800 px-2 mr-1 rounded" phx-value-client_id={@client.id} phx-value={tag}>
              <%= String.capitalize(tag) %>
              <%= if tag not in @job_types do %>
                <a class="text-gray-800 hover:text-gray-600" phx-click="delete-tag" phx-value-client_id={@client.id} phx-value-tag={tag}>&times</a>
              <% end %>
            </span>
            <% end %>
        <% end %>
        <span class="cursor-pointer">
          <%= if Ecto.Changeset.get_field(@tags_changeset, :client_id) == @client.id do%>
            <div class="relative flex">
              <input type="text" autofocus class="border-gray-600 border-2 pl-2 rounded w-24" id={"save-tags-client-#{@client.id}"} name="client_tag_values" phx-debounce="500" spellcheck="false" placeholder="Add tag..." phx-window-keydown="save-tags" phx-value-client_id={@client.id} />
              <a class="absolute top-0 bottom-0 flex flex-row items-center text-xs text-gray-400 mr-1 right-0">
                <span phx-click="close-tags" phx-value-client-id={@client.id} class="cursor-pointer">
                  <.icon name="close-x" class="w-3 fill-current stroke-current stroke-2 close-icon text-gray-600" />
                </span>
              </a>
            </div>
          <% else %>
            <.icon_button_simple class="flex flex-shrink-0 ml-2 bg-white border rounded border-gray-600 text-gray-600" color="gray-400" phx-click="add-tags" phx-value-client_id={"#{@client.id}"} icon="plus"></.icon_button_simple>
          <% end %>
        </span>
      </div>
    """
  end

  def actions(assigns) do
    ~H"""
    <div class="flex items-center left-3 sm:left-8" data-offset-x="-21" phx-update="ignore" data-placement="bottom-end" phx-hook="Select" id={"manage-client-#{@client.id}"}>
      <button title="Manage" type="button" class="flex flex-shrink-0 p-1 text-2xl font-bold bg-white border rounded border-blue-planning-300 text-blue-planning-300">
        <.icon name="hellip" class="w-4 h-1 m-1 fill-current open-icon text-blue-planning-300" />

        <.icon name="close-x" class="hidden w-3 h-3 mx-1.5 stroke-current close-icon stroke-2 text-blue-planning-300" />
      </button>

      <div class="z-10 flex flex-col hidden w-44 bg-white border rounded-lg shadow-lg popover-content">
        <button title="Edit" type="button" phx-click="edit-client" phx-value-id={@client.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
          <.icon name="pencil" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
          Details
        </button>
        <button title="send-email" type="button" phx-click="open-compose" phx-value-client_id={@client.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
          <.icon name="envelope" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
          Send email
        </button>
        <button title="Create a lead" type="button" phx-click="create-lead" phx-value-id={@client.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
          <.icon name="three-people" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
          Create a lead
        </button>
        <button title="Create gallery" type="button" phx-click="create-gallery" phx-value-id={@client.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
          <.icon name="gallery" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
          Create gallery
        </button>
        <button title="Import job" type="button" phx-click="import-job" phx-value-id={@client.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
          <.icon name="camera-check" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
          Import job
        </button>
        <button title="Archive" type="button" phx-click="confirm-archive" phx-value-id={@client.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
          <.icon name="trash" class="inline-block w-4 h-4 mr-3 fill-current text-red-sales-300" />
          Archive
        </button>
      </div>
    </div>
    """
  end

  defp save_tags(client_id, new_tags, client) do
    old_tags = client.tags |> Enum.map(& &1.name)

    changesets =
      Enum.reduce(new_tags, [], fn tag, acc ->
        if tag in old_tags do
          acc
        else
          [
            %{
              name: String.trim(tag) |> String.downcase(),
              client_id: client_id,
              inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
              updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
            }
            | acc
          ]
        end
      end)

    {_count, _tag_records} = Repo.insert_all(ClientTag, changesets)
  end

  defp reset_pagination(%{limit: limit, total_count: total_count}),
    do: %Pagination{
      limit: limit,
      first_index: 1,
      last_index: limit,
      before: nil,
      after: nil,
      total_count: total_count
    }

  defp assign_clients(socket) do
    socket
    |> assign(:job_status, "all")
    |> assign(:job_type, "all")
    |> assign(:sort_by, "newest")
    |> assign(:sort_col, "inserted_at")
    |> assign(:sort_direction, "desc")
    |> assign(:search_results, [])
    |> assign(:search_phrase, nil)
    |> assign(:searched_client, nil)
    |> assign(:new_client, false)
    |> assign(current_focus: -1)
    |> assign(:tags_changeset, tag_default_changeset(%{}))
    |> assign(:job_types, Picsello.JobType.all())
    |> assign_new(:selected_client, fn -> nil end)
    |> then(fn socket ->
      socket
      |> fetch_clients()
    end)
  end

  defp open_confirmation_component(socket, client),
    do:
      socket
      |> ConfirmationComponent.open(%{
        close_label: "No, go back",
        confirm_event: "archive_" <> to_string(client.id),
        confirm_label: "Yes, archive",
        icon: "warning-orange",
        title: "Archive Client?",
        subtitle: "Are you sure you wish to archive #{client.name || "this client"}?"
      })
      |> noreply()

  def tag_default_changeset(params) do
    ClientTag.create_changeset(params)
  end

  defp fetch_clients(
         %{
           assigns: %{
             current_user: user,
             job_status: status,
             job_type: type,
             sort_col: sort_by,
             sort_direction: sort_direction,
             search_phrase: search_phrase,
             pagination: pagination
           }
         } = socket
       ) do
    clients =
      Clients.find_all_by(
        user: user,
        filters: %{
          status: status,
          type: type,
          sort_by: String.to_atom(sort_by),
          sort_direction: String.to_atom(sort_direction),
          search_phrase: search_phrase
        },
        pagination: pagination
      )
      |> Repo.all()

    socket
    |> assign(
      clients: clients,
      pagination: %{
        pagination
        | total_count: Repo.aggregate(Client, :count, :id),
          last_index: pagination.first_index + Enum.count(clients) - 1
      }
    )
  end

  defp fetch_clients(%{assigns: %{current_user: current_user, client: client}} = socket) do
    socket
    |> assign(:client, Clients.get_client(client.id, current_user))
  end

  defp job_status_options do
    [
      %{title: "All", id: "all"},
      %{title: "Active Jobs", id: "active_jobs"},
      %{title: "Past Jobs", id: "past_jobs"},
      %{title: "Leads", id: "leads"}
    ]
  end

  def job_type_options(job_types) do
    types =
      job_types
      |> Enum.map(fn type -> %{title: String.capitalize(type), id: type} end)

    [%{title: "All", id: "all"} | types]
  end

  defp sort_options do
    [
      %{title: "Name", id: "name", column: "name", direction: "desc"},
      %{title: "# of jobs", id: "no_of_jobs", column: "id", direction: "desc"},
      %{title: "Oldest", id: "oldest", column: "inserted_at", direction: "asc"},
      %{title: "Newest", id: "newest", column: "inserted_at", direction: "desc"}
    ]
  end
end
