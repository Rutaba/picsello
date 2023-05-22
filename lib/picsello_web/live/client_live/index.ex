defmodule PicselloWeb.Live.ClientLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view

  import PicselloWeb.GalleryLive.Index, only: [update_gallery_listing: 1]
  import PicselloWeb.GalleryLive.Shared, only: [add_message_and_notify: 2, new_gallery_path: 2]

  import PicselloWeb.Shared.CustomPagination,
    only: [
      pagination_component: 1,
      assign_pagination: 2,
      update_pagination: 2,
      reset_pagination: 2,
      pagination_index: 2
    ]

  alias Ecto.Changeset
  alias Picsello.{Repo, Clients, ClientTag}
  alias PicselloWeb.JobLive.{NewComponent, ImportWizard, Shared}

  alias PicselloWeb.{
    ConfirmationComponent,
    SuccessComponent,
    Live.ClientLive.ClientFormComponent,
    GalleryLive.CreateComponent
  }

  @default_pagination_limit 12

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Clients")
    |> assign_pagination(@default_pagination_limit)
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
    socket
    |> assign(
      :tags_changeset,
      ClientTag.create_changeset(%{
        client_id: to_integer(client_id)
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
    client = clients |> Enum.find(&(&1.id == to_integer(id)))
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
        %{"direction" => _direction} = params,
        socket
      ) do
    socket
    |> update_pagination(params)
    |> fetch_clients()
    |> noreply()
  end

  @impl true
  def handle_event(
        "page",
        %{"custom_pagination" => %{"limit" => _limit}} = params,
        socket
      ) do
    socket
    |> update_pagination(params)
    |> fetch_clients()
    |> noreply()
  end

  @impl true
  def handle_event("page", %{}, socket), do: socket |> noreply()

  @impl true
  def handle_event(
        "search",
        %{"search_phrase" => search_phrase},
        socket
      ) do
    search_phrase = String.trim(search_phrase)

    search_phrase =
      if String.length(search_phrase) > 0, do: String.downcase(search_phrase), else: nil

    socket
    |> assign(search_phrase: search_phrase)
    |> reassign_pagination_and_clients()
  end

  @impl true
  def handle_event("clear-search", _, socket) do
    socket
    |> assign(:search_phrase, nil)
    |> reassign_pagination_and_clients()
  end

  @impl true
  def handle_event(
        "apply-filter-status",
        %{"option" => status},
        socket
      ) do
    socket
    |> assign(:job_status, status)
    |> reassign_pagination_and_clients()
  end

  @impl true
  def handle_event(
        "apply-filter-type",
        %{"option" => type},
        socket
      ) do
    socket
    |> assign(:job_type, type)
    |> reassign_pagination_and_clients()
  end

  @impl true
  def handle_event(
        "apply-filter-sort_by",
        %{"option" => sort_by},
        socket
      ) do
    socket
    |> assign(:sort_by, sort_by)
    |> assign(:sort_col, Enum.find(sort_options(), fn op -> op.id == sort_by end).column)
    |> assign(:sort_direction, Enum.find(sort_options(), fn op -> op.id == sort_by end).direction)
    |> reassign_pagination_and_clients()
  end

  @impl true
  def handle_event(
        "sort_direction",
        _,
        %{assigns: %{desc: desc}} = socket
      ) do
    socket
    |> assign(:desc, !desc)
    |> reassign_pagination_and_clients()
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
    client = clients |> Enum.find(&(&1.id == to_integer(id)))

    socket
    |> open_modal(NewComponent, %{
      current_user: current_user,
      selected_client: client
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "import-job",
        %{"id" => id},
        %{assigns: %{clients: clients, current_user: current_user}} = socket
      ) do
    client = clients |> Enum.find(&(&1.id == to_integer(id)))

    socket
    |> open_modal(ImportWizard, %{
      current_user: current_user,
      selected_client: client,
      step: :job_details
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "import-job",
        %{"id" => _id},
        %{assigns: %{client: client, current_user: current_user}} = socket
      ) do
    socket
    |> open_modal(ImportWizard, %{
      current_user: current_user,
      selected_client: client,
      step: :job_details
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "create-gallery",
        %{"id" => id},
        %{assigns: %{clients: clients, current_user: current_user}} = socket
      ) do
    client = clients |> Enum.find(&(&1.id == to_integer(id)))

    socket
    |> open_modal(CreateComponent, %{
      current_user: current_user,
      selected_client: client
    })
    |> noreply()
  end

  def handle_info({:success_event, "view-gallery", %{gallery_id: gallery_id}}, socket) do
    socket
    |> push_redirect(to: Routes.gallery_photographer_index_path(socket, :index, gallery_id, is_mobile: false))
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
  def handle_info({:redirect_to_gallery, gallery}, socket) do
    socket
    |> push_redirect(to: new_gallery_path(socket, gallery))
    |> noreply()
  end

  @impl true
  def handle_info({:confirm_event, "archive_" <> id}, socket) do
    case Clients.archive_client(id) do
      {:ok, _client} ->
        socket
        |> put_flash(:success, "Client archived successfully")

      {:error, _} ->
        socket
        |> close_modal()
        |> put_flash(:error, "Error archiving client")
    end
    |> push_redirect(to: Routes.clients_path(socket, :index))
    |> noreply()
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
    <div id={@id} class={"relative w-full mt-3 md:mt-0 w-full"} data-offset-y="10" phx-hook="Select">
      <h4 class="font-extrabold text-sm mb-1"><%= @title %></h4>
      <div class="flex flex-row items-center border rounded-lg p-3">
          <span class="flex-shrink-0"><%= String.capitalize(String.replace(@selected_option, "_", " ")) %></span>
          <.icon name="down" class="flex-shrink-0 w-3 h-3 ml-auto lg:mr-2 mr-1 stroke-current stroke-2 open-icon" />
          <.icon name="up" class="flex-shrink-0 hidden w-3 h-3 ml-auto lg:mr-2 mr-1 stroke-current stroke-2 close-icon" />
      </div>
      <ul class="absolute z-30 hidden w-full md:w-32 mt-2 bg-white toggle rounded-md popover-content border shadow-lg">
        <%= for option <- @options_list do %>
          <li id={option.id} target-class="toggle-it" parent-class="toggle" toggle-type="selected-active" phx-hook="ToggleSiblings"
          class="flex items-center py-1.5 hover:bg-blue-planning-100 hover:rounded-md">
            <button id={option.id} class="album-select" phx-click={"apply-filter-#{@id}"} phx-value-option={option.id}><%= option.title %></button>
            <%= if option.id == @selected_option do %>
              <.icon name="tick" class="w-6 h-5 mr-1 toggle-it text-blue-planning-300" />
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
          <%= if Changeset.get_field(@tags_changeset, :client_id) == @client.id do%>
            <div class="relative flex">
              <input type="text" autofocus class="border-gray-600 border-2 pl-2 rounded w-24" id={"save-tags-client-#{@client.id}"} name="client_tag_values" phx-debounce="500" spellcheck="false" placeholder="Add tag..." phx-window-keydown="save-tags" phx-value-client_id={@client.id} />
              <a class="absolute top-0 bottom-0 flex flex-row items-center text-xs text-gray-400 mr-1 right-0">
                <span phx-click="close-tags" phx-value-client-id={@client.id} class="cursor-pointer">
                  <.icon name="close-x" class="w-3 fill-current stroke-current stroke-2 close-icon text-gray-600" />
                </span>
              </a>
            </div>
          <% else %>
            <.icon_button_simple class="flex flex-shrink-0 ml-2 bg-white border rounded border-gray-600 text-gray-600" color="gray-400" phx-click="add-tags" phx-value-client_id={"#{@client.id}"} icon="plus" icon_class="w-2 h-3"></.icon_button_simple>
          <% end %>
        </span>
      </div>
    """
  end

  def actions(assigns) do
    ~H"""
    <div class="flex items-center md:ml-auto w-full md:w-auto left-3 sm:left-8" data-offset-x="-21" phx-update="ignore" data-placement="bottom-end" phx-hook="Select" id={"manage-client-#{@client.id}"}>
      <button title="Manage" class="btn-tertiary px-2 py-1 flex items-center gap-3 mr-2 text-blue-planning-300 xl:w-auto w-full" id="Manage">
        Actions
        <.icon name="down" class="w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 open-icon" />
        <.icon name="up" class="hidden w-4 h-4 ml-auto mr-1 stroke-current stroke-3 text-blue-planning-300 close-icon" />
      </button>

      <div class="z-10 flex flex-col hidden w-44 bg-white border rounded-lg shadow-lg popover-content">
        <%= for %{title: title, action: action, icon: icon} <- actions() do %>
          <button title={title} type="button" phx-click={action} phx-value-id={@client.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
            <.icon name={icon} class={classes("inline-block w-4 h-4 mr-3 fill-current", %{"text-red-sales-300" => icon == "trash", "text-blue-planning-300" => icon != "trash"})} />
            <%= title %>
          </button>
        <% end %>
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

  defp assign_clients(socket) do
    socket
    |> assign(:job_status, "all")
    |> assign(:job_type, "all")
    |> assign(:sort_by, "name")
    |> assign(:sort_col, "name")
    |> assign(:sort_direction, "asc")
    |> assign(:search_results, [])
    |> assign(:search_phrase, nil)
    |> assign(:searched_client, nil)
    |> assign(:new_client, false)
    |> assign(current_focus: -1)
    |> assign(:tags_changeset, tag_default_changeset(%{}))
    |> assign(:job_types, Picsello.JobType.all())
    |> assign_new(:selected_client, fn -> nil end)
    |> fetch_clients()
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
             pagination_changeset: pagination_changeset
           }
         } = socket
       ) do
    pagination = pagination_changeset |> Changeset.apply_changes()

    clients =
      Clients.find_all_by_pagination(
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
    |> assign(clients: clients)
    |> update_pagination(%{
      total_count:
        if(pagination.total_count == 0,
          do: client_count(socket),
          else: pagination.total_count
        ),
      last_index: pagination.first_index + Enum.count(clients) - 1
    })
  end

  defp client_count(%{
         assigns: %{
           current_user: user,
           job_status: status,
           job_type: type,
           sort_col: sort_by,
           sort_direction: sort_direction,
           search_phrase: search_phrase
         }
       }) do
    Clients.find_all_by(
      user: user,
      filters: %{
        status: status,
        type: type,
        sort_by: String.to_atom(sort_by),
        sort_direction: String.to_atom(sort_direction),
        search_phrase: search_phrase
      }
    )
    |> Repo.all()
    |> Enum.count()
  end

  defp reassign_pagination_and_clients(%{assigns: %{pagination_changeset: changeset}} = socket) do
    limit = pagination_index(changeset, :limit)

    socket
    |> reset_pagination(%{limit: limit, last_index: limit, total_count: client_count(socket)})
    |> fetch_clients()
    |> noreply()
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

  defp actions do
    [
      %{title: "Details", action: "edit-client", icon: "pencil"},
      %{title: "Send email", action: "open-compose", icon: "envelope"},
      %{title: "Create a lead", action: "create-lead", icon: "three-people"},
      %{title: "Create gallery", action: "create-gallery", icon: "gallery"},
      %{title: "Import job", action: "import-job", icon: "camera-check"},
      %{title: "Archive", action: "confirm-archive", icon: "trash"}
    ]
  end
end
