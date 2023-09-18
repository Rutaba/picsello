defmodule PicselloWeb.InboxLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Job, Jobs, Repo, ClientMessage, Notifiers.ClientNotifier, Messages}
  import Ecto.Query
  import Picsello.Galleries.Workers.PhotoStorage, only: [path_to_url: 1]

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Inbox")
    |> assign_unread()
    |> subscribe_inbound_messages()
    |> assign(:current_thread_type, nil)
    |> assign(:tabs, tabs_list())
    |> ok()
  end

  @impl true
  def handle_params(%{"id" => thread_id} = params, _uri, socket) do
    [current_thread_type, thread_id] = String.split(thread_id, "-")

    socket
    |> assign_tab(params)
    |> assign(:current_thread_type, String.to_atom(current_thread_type))
    |> assign_tab_data()
    |> assign_unread()
    |> assign_current_thread(thread_id)
    |> noreply()
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket
    |> assign_tab(params)
    |> assign_tab_data()
    |> noreply()
  end

  defp assign_tab(socket, params), do: assign(socket, :tab_active, params["type"] || "all")

  @impl true
  def render(assigns) do
    ~H"""
    <div class={classes(%{"hidden sm:block" => @current_thread})} {intro(@current_user, "intro_inbox")}><h1 class="px-6 py-10 text-4xl font-bold center-container" {testid("inbox-title")}>Inbox</h1></div>
    <div class={classes("center-container pb-6", %{"pt-0" => @current_thread})}>
      <div class={classes("flex flex-col sm:flex-row bg-gray-100 py-6 items-center mb-6 px-4 rounded-lg", %{"hidden sm:flex" => @current_thread})}>
        <h2 class="font-bold text-2xl mb-4">Viewing all messages</h2>
        <div class="flex sm:ml-auto gap-3">
          <%= for %{name: name, action: action, concise_name: concise_name} <- @tabs do %>
            <button class={classes("border rounded-lg border-blue-planning-300 text-blue-planning-300 py-1 px-4", %{"text-white bg-blue-planning-300" => @tab_active === concise_name, "hover:opacity-100" => @tab_active !== concise_name})} type="button" phx-click={action} phx-value-tab={concise_name}><%= name %></button>
          <% end %>
        </div>
      </div>

      <div class="flex sm:h-[calc(100vh-18rem)]">
        <div class={classes("border-t w-full lg:w-1/3 overflow-y-auto flex-shrink-0", %{"hidden sm:block" => @current_thread, "hidden" => Enum.empty?(@threads)})}>
          <%= for thread <- @threads do %>
            <.thread_card {thread} unread={member?(assigns, thread.id)} selected={@current_thread && thread.id == @current_thread.id && @current_thread_type == thread.type} />
          <% end %>
        </div>
        <%= cond do %>
          <% @current_thread != nil -> %>
            <.current_thread {@current_thread} current_thread_type={@current_thread_type} socket={@socket} />
          <% Enum.empty?(@threads) -> %>
            <div class="flex w-full items-center justify-center p-6 border m-5">
              <div class="flex items-center flex-col text-blue-planning-300 text-xl">
                <.icon name="envelope" class="text-blue-planning-300 w-20 h-20" />
                <p class="text-center">You don’t have any new messages.</p>
                <p class="text-center">Go to a job or lead to send a new message.</p>
              </div>
            </div>
          <% true -> %>
            <div class="hidden sm:flex w-2/3 items-center justify-center border ml-4 rounded-lg">
              <div class="flex items-center">
                <.icon name="envelope" class="text-blue-planning-300 w-20 h-32" />
                <p class="ml-4 text-blue-planning-300 text-xl w-52">No message selected</p>
              </div>
            </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp thread_card(assigns) do
    ~H"""
    <div {testid("thread-card")} phx-click="open-thread" phx-value-id={@id} phx-value-type={@type} class={classes("flex justify-between py-6 border-b pl-2 p-8 cursor-pointer", %{"bg-blue-planning-300 rounded-lg text-white" => @selected, "hover:bg-gray-100 hover:text-black" => !@selected})}>
      <div class="px-4">
        <div class="flex items-center">
          <div class="font-bold	text-2xl line-clamp-1">
            <%= if String.length(@title)>12 do %>
              <%= String.slice(@title, 0..12) <> "..."%>
            <% else %>
              <%= @title %>
            <% end %>
          </div>
          <%= if @unread do %>
            <span {testid("new-badge")} class="mx-4 px-2 py-0.5 text-xs rounded bg-orange-inbox-300 text-white">New</span>
          <% end %>
        </div>
        <div class="line-clamp-1 font-semibold py-0.5">
          <%= if String.length(@subtitle)>17 do %>
              <%= String.slice(@subtitle, 0..4) <> "..." <> " " <> (String.split(@subtitle, " ") |> List.last())  %>
          <% else %>
            <%= @subtitle %>
          <% end %>
        </div>
        <%= if (@message) do %>
          <div class={classes("line-clamp-1", %{"w-48" => String.length(@message) > 28})}><%= raw @message %></div>
        <% end %>
        <span class="px-2 py-0.5 text-xs font-semibold rounded bg-blue-planning-100 text-blue-planning-300 capitalize"><%= @type %></span>
      </div>
      <div class="relative flex flex-shrink-0">
        <%= @date %>
        <.icon name="forth" class="sm:hidden absolute top-1.5 -right-6 w-4 h-4 stroke-current text-base-300 stroke-2" />
      </div>
    </div>
    """
  end

  defp current_thread(assigns) do
    ~H"""
      <div class="flex flex-col w-full sm:overflow-y-auto sm:border rounded-lg ml-2">
          <div class="sticky z-10 top-0 px-6 py-3 flex shadow-sm sm:shadow-none bg-base-200">
            <.live_link to={Routes.inbox_path(@socket, :index)} class="sm:hidden pt-2 pr-4">
              <.icon name="left-arrow" class="w-6 h-6" />
            </.live_link>
            <div>
              <div class="sm:font-semibold text-2xl line-clamp-1 text-blue-planning-300"><%= @title %></div>
            </div>
            <button title="Delete" type="button" phx-click="confirm-delete" class="ml-auto flex items-center hover:opacity-80">
              <.icon name="trash" class="sm:w-5 sm:h-5 w-6 h-6 mr-3 text-red-sales-300" />
            </button>
          </div>
            <div class="bg-white sticky top-14 z-10 pt-4">
              <div class="flex items-center ml-4">
              <%= if @current_thread_type == :client do %>
                <.icon name="client-icon" class="text-blue-planning-300 w-6 h-6 mr-2" />
              <% else %>
                <.icon name="camera-check" class="text-blue-planning-300 w-6 h-6 mr-2" />
              <% end %>
                <%= case @current_thread_type do %>
                  <% :client -> %>
                    <.view_link name="View client" route={Routes.client_path(@socket, :show, @id)} />
                  <% :job -> %>
                    <%= if @is_lead do %>
                      <.view_link name="View lead" route={Routes.job_path(@socket, :leads, @id)} />
                    <% else %>
                      <.view_link name="View job" route={Routes.job_path(@socket, :jobs, @id)} />
                    <% end %>
                  <% end %>
              </div>
              <hr class="my-4 sm:my-4" />
            </div>
          <div class="flex flex-1 flex-col p-6">
            <%= for message <- @messages do %>
              <%= if message.is_first_unread do %>
                <div class="flex items-center my-1">
                  <div class="flex-1 h-px bg-orange-inbox-300"></div>
                  <div class="text-orange-inbox-300 px-4">new message</div>
                  <div class="flex-1 h-px bg-orange-inbox-300"></div>
                </div>
              <% end %>

              <div {testid("thread-message")} {scroll_to_message(message)} class="m-2" style="scroll-margin-bottom: 7rem">
                <div class={classes("mb-3 flex justify-between items-end", %{"flex-row-reverse" => message.outbound})}>

                  <div class="mx-1">
                    <%= unless message.same_sender do %>
                      <%= message.sender %> wrote:
                    <% end %>
                  </div>
                </div>

                <div class={classes("flex items-center font-bold text-xl px-4 py-2", %{"rounded-t-lg" => message.collapsed_sections, "rounded-lg" => !message.collapsed_sections, "bg-blue-planning-300 text-white" => message.outbound, "bg-gray-300" => !message.outbound})} phx-click="collapse-section" phx-value-id={message.id}>
                  <%= message.subject %>
                  <%= if message.unread do %>
                      <span {testid("new-badge")} class="mx-4 px-2 py-0.5 text-xs rounded bg-orange-inbox-300 text-white">New</span>
                  <% end %>
                  <div class="flex gap-2 text-xs ml-auto">
                    <%= message.date %>
                    <%= if message.collapsed_sections do %>
                      <.icon name="down" class="w-4 h-4 stroke-current stroke-2" />
                    <% else %>
                      <.icon name="up" class="w-4 h-4 stroke-current stroke-2" />
                    <% end %>
                  </div>
                </div>
                <%= if message.collapsed_sections do %>
                  <div class="flex border px-4 py-2 text-base-250">
                    <div class="flex flex-col">
                      <p> To: <%= message.receiver %> </p>
                      <%= if(message.show_cc?) do %>
                        <p> Cc: <%= message.cc %> </p>
                        <p> Bcc: <%= message.bcc %> </p>
                      <% end %>
                    </div>
                    <div class={"ml-auto text-blue-planning-300 underline cursor-pointer #{@current_thread_type == :client && 'hidden'}"} phx-click="show-cc" phx-value-id={message.id}>
                      <%= if(message.show_cc?) do %>
                        Hide Cc/Bcc
                      <% else %>
                        Show Cc/Bcc
                      <% end %>
                    </div>
                  </div>
                  <div class="flex flex-col relative border rounded-b-lg p-6">
                    <span class="whitespace-pre-line"><%= raw message.body %></span>

                    <%= unless Enum.empty?(message.client_message_attachments) do %>
                      <div class="p-2 border mt-4 rounded-lg">
                        <h4 class="text-sm mb-2 font-bold">Client attachments:</h4>
                        <div class="flex flex-col gap-2">
                          <%= for client_attachment <- message.client_message_attachments do %>
                            <a href={path_to_url(client_attachment.url)} target="_blank">
                              <div class="text-sm text-blue-planning-300 bg-base-200 border border-base-200 hover:bg-white transition-colors duration-300 px-2 py-1 rounded-lg flex items-center">
                                <.icon name="paperclip" class="w-4 h-4 mr-1" /> <%= client_attachment.name %>
                              </div>
                            </a>
                          <% end %>
                        </div>
                      </div>
                    <% end %>

                    <%= if message.read_at do %>
                      <span class="ml-auto text-base-250 text-sm">
                          <%= message.read_at %>
                      </span>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>

          </div>
          <div class="sticky bottom-0 bg-white flex flex-col p-6 sm:pr-8 bg-white sm:flex-row-reverse">
            <button class="btn-primary" phx-click="compose-message" phx-value-thread-id={@id}>
              Reply
            </button>
          </div>
      </div>
    """
  end

  defp view_link(assigns) do
    ~H"""
      <.live_link to={@route} class="flex gap-2 items-center rounded-lg bg-gray-100 py-1 px-4 text-blue-planning-300">
        <%= @name %>
        <.icon name="forth" class="stroke-2 h-3 w-2 mt-1" />
      </.live_link>
    """
  end

  defp member?(
         %{
           unread_job_ids: unread_job_ids,
           unread_client_ids: unread_client_ids,
           current_thread_type: type
         },
         thread_id
       ) do
    case type do
      :job -> is_map_key(unread_job_ids, thread_id)
      _ -> is_map_key(unread_client_ids, thread_id)
    end
  end

  def scroll_to_message(message) do
    if message.scroll do
      %{phx_hook: "ScrollIntoView", id: "message-#{message.id}"}
    else
      %{}
    end
  end

  @impl true
  def handle_event(
        "open-thread",
        %{"id" => id, "type" => type},
        %{assigns: %{tab_active: tab}} = socket
      ) do
    socket
    |> push_patch(to: Routes.inbox_path(socket, :show, "#{type}-#{id}", type: tab))
    |> noreply()
  end

  @impl true
  def handle_event("change-tab", %{"tab" => tab}, socket) do
    socket
    |> push_patch(to: Routes.inbox_path(socket, :index, type: tab))
    |> noreply()
  end

  @impl true
  def handle_event("show-cc", %{"id" => id}, socket) do
    new_messages =
      Enum.map(socket.assigns.current_thread.messages, fn entry ->
        if entry.id == String.to_integer(id) do
          show_cc? = Map.get(entry, :show_cc?, false)
          Map.update!(entry, :show_cc?, fn _ -> !show_cc? end)
        else
          entry
        end
      end)

    socket
    |> assign(
      :current_thread,
      %{
        socket.assigns.current_thread
        | messages: new_messages
      }
    )
    |> noreply()
  end

  @impl true
  def handle_event(
        "collapse-section",
        %{"id" => id},
        %{assigns: %{current_thread: %{messages: messages} = current_thread}} = socket
      ) do
    new_messages =
      Enum.map(messages, fn entry ->
        if entry.id == String.to_integer(id) do
          collapsed_sections = Map.get(entry, :collapsed_sections, false)
          Map.update!(entry, :collapsed_sections, fn _ -> !collapsed_sections end)
        else
          entry
        end
      end)

    socket
    |> assign(:current_thread, %{current_thread | messages: new_messages})
    |> noreply()
  end

  @impl true
  def handle_event(
        "compose-message",
        %{},
        %{assigns: %{job: job, current_user: current_user, current_thread_type: :job}} = socket
      ) do
    socket
    |> PicselloWeb.ClientMessageComponent.open(%{
      subject: Job.name(job),
      current_user: current_user,
      enable_size: true,
      enable_image: true,
      client: Job.client(job)
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "compose-message",
        %{"thread-id" => thread_id},
        %{assigns: %{current_user: current_user, current_thread_type: :client}} = socket
      ) do
    client = Picsello.Clients.get_client!(thread_id)

    socket
    |> PicselloWeb.ClientMessageComponent.open(%{
      current_user: current_user,
      enable_size: true,
      enable_image: true,
      client: client
    })
    |> noreply()
  end

  @impl true
  def handle_event("confirm-delete", %{}, socket) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      close_label: "Cancel",
      confirm_event: "delete",
      confirm_label: "Yes, delete",
      icon: "warning-orange",
      title: "Remove Conversation?",
      subtitle: "This will remove the conversation from Inbox and cannot be undone."
    })
    |> noreply()
  end

  @impl true
  def handle_event("intro_js" = event, params, socket),
    do: PicselloWeb.LiveHelpers.handle_event(event, params, socket)

  defp assign_threads(%{assigns: %{current_user: current_user, tab_active: tab}} = socket) do
    tab
    |> then(fn
      "job" ->
        Messages.job_threads(current_user)

      "client" ->
        Messages.client_threads(current_user)

      "all" ->
        current_user
        |> Messages.job_threads()
        |> Enum.concat(Messages.client_threads(current_user))
        |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
    end)
    |> Enum.map(fn message ->
      %{
        id: message.job_id || hd(message.client_message_recipients).client_id,
        title: thread_title(message),
        subtitle: if(message.job, do: Job.name(message.job), else: "CLIENTS SUBTITLE"),
        message: if(message.body_text, do: message.body_text, else: message.body_html),
        type: thread_type(message),
        date: strftime(current_user.time_zone, message.inserted_at, "%a %b %d, %-I:%M %p")
      }
    end)
    |> then(&assign(socket, :threads, &1))
  end

  defp thread_type(%{job_id: nil}), do: :client
  defp thread_type(_message), do: :job

  defp thread_title(%{client_message_recipients: [%{client: %{name: name}} | _]}), do: name
  defp thread_title(%{job: %{client: %{name: name}}}), do: name
  defp thread_title(_), do: "name"

  defp assign_unread(%{assigns: %{current_user: current_user}} = socket) do
    {job_ids, client_ids, message_ids} = Messages.unread_messages(current_user)

    socket
    |> assign(:unread_message_ids, Map.new(message_ids, &{&1, &1}))
    |> assign(:unread_job_ids, Map.new(job_ids, &{&1, &1}))
    |> assign(:unread_client_ids, Map.new(client_ids, &{&1, &1}))
  end

  defp assign_current_thread(socket, thread_id, message_id_to_scroll \\ nil)

  defp assign_current_thread(
         %{assigns: %{current_thread_type: :job}} = socket,
         thread_id,
         message_id_to_scroll
       ) do
    %{client: %{name: name}, job_status: job_status} =
      job = Jobs.get_job_by_id(thread_id) |> Repo.preload([:client, :job_status])

    client_messages = Messages.for_job(job)

    socket
    |> assign(:current_thread, %{
      id: job.id,
      messages: build_messages(socket, client_messages, message_id_to_scroll),
      title: name,
      subtitle: Job.name(job),
      is_lead: job_status.is_lead
    })
    |> assign(:job, job)
    |> mark_current_thread_as_read()
  end

  defp assign_current_thread(
         %{
           assigns: %{
             current_thread_type: :client
           }
         } = socket,
         thread_id,
         message_id_to_scroll
       ) do
    client = Picsello.Clients.get_client!(thread_id)
    client_messages = Messages.for_client(client)

    socket
    |> assign(:current_thread, %{
      id: client.id,
      messages: build_messages(socket, client_messages, message_id_to_scroll),
      title: client.name,
      subtitle: "Client Subtitle",
      is_lead: false
    })
    |> assign(:job, nil)
    |> assign(:client, client)
    |> mark_current_thread_as_read()
  end

  defp build_messages(
         %{
           assigns: %{
             current_user: %{time_zone: time_zone},
             unread_message_ids: unread_message_ids,
             current_thread_type: current_thread_type
           }
         },
         client_messages,
         message_id_to_scroll
       ) do
    length = length(client_messages)

    client_messages
    |> Enum.with_index(1)
    |> Enum.reduce(
      %{last: nil, messages: []},
      fn {%{
            client_message_recipients: recipients,
            outbound: outbound,
            body_text: body_text,
            body_html: body_html,
            read_at: read_at
          } = message, index},
         %{last: last, messages: messages} ->
        {sender, receiver} =
          message
          |> extract_client()
          |> get_sender_receiver(recipients, outbound, current_thread_type)

        %{
          last: message,
          messages:
            messages ++
              [
                %{
                  id: message.id,
                  body: if(body_text, do: body_text, else: body_html),
                  date: strftime(time_zone, message.inserted_at, "%a %b %-d, %-I:%0M %p"),
                  outbound: outbound,
                  sender: sender,
                  receiver: receiver,
                  cc: assign_message_recipients(message, :cc),
                  bcc: assign_message_recipients(message, :bcc),
                  subject: message.subject,
                  same_sender: last && last.outbound == outbound,
                  is_first_unread: Enum.member?(unread_message_ids, message.id),
                  scroll: message.id == message_id_to_scroll || index == length,
                  unread: message.read_at == nil,
                  client_message_attachments: message.client_message_attachments,
                  show_cc?: false,
                  collapsed_sections: true,
                  read_at: if(read_at, do: strftime(time_zone, read_at, "%a, %B %d, %I:%M:%S %p"))
                }
              ]
        }
      end
    )
    |> Map.get(:messages)
  end

  defp get_sender_receiver(client, recipients, outbound, :job) do
    sender = (outbound && "You") || client.name
    recipient = Enum.find(recipients, &(&1.recipient_type == :to))
    client = (recipient && recipient.client) || client
    receiver = (outbound && client.email) || "You"

    {sender, receiver}
  end

  defp get_sender_receiver(client, _recipients, outbound, :client) do
    sender = (outbound && "You") || client.name
    receiver = (outbound && client.email) || "You"

    {sender, receiver}
  end

  defp extract_client(%{client_message_recipients: [%{client: client} | _]}), do: client
  defp extract_client(%{job: %{client: client}}), do: client

  defp assign_message_recipients(%{client_message_recipients: client_message_recipients}, type) do
    client_message_recipients
    |> Enum.filter(&(&1.recipient_type == type))
    |> Enum.map(& &1.client_id)
    |> Picsello.Clients.fetch_multiple()
    |> case do
      [] -> nil
      clients -> Enum.map_join(clients, ";", & &1.email)
    end
  end

  @tabs [{"All", "all"}, {"Jobs/Leads", "job"}, {"Clients", "client"}]
  defp tabs_list() do
    Enum.map(@tabs, fn {name, concise_name} ->
      %{
        name: name,
        concise_name: concise_name,
        action: "change-tab"
      }
    end)
  end

  defp assign_tab_data(socket) do
    socket
    |> assign_threads()
    |> assign(:current_thread, nil)
  end

  defp mark_current_thread_as_read(
         %{assigns: %{current_thread: %{id: id}, current_thread_type: type}} = socket
       ) do
    if connected?(socket) do
      Messages.update_all(id, type)
    end

    socket
  end

  defp subscribe_inbound_messages(%{assigns: %{current_user: current_user}} = socket) do
    Phoenix.PubSub.subscribe(
      Picsello.PubSub,
      "inbound_messages:#{current_user.organization_id}"
    )

    socket
  end

  def handle_info(
        {:inbound_messages, message},
        %{assigns: %{current_thread: current_thread}} = socket
      ) do
    socket
    |> assign_threads()
    |> assign_unread()
    |> then(fn socket ->
      if current_thread do
        assign_current_thread(socket, current_thread.id, message.id)
      else
        socket
      end
    end)
    |> noreply()
  end

  def handle_info(
        {:message_composed, message_changeset, recipients},
        %{assigns: %{job: job, current_user: user, client: client}} = socket
      ) do
    thread_id = (job && job.id) || client.id

    with {:ok, %{client_message: message, client_message_recipients: _}} <-
           add_message(message_changeset, job, recipients, user),
         {:ok, _email} <- ClientNotifier.deliver_email(message, recipients) do
      socket
      |> close_modal()
      |> assign_threads()
      |> assign_current_thread(thread_id, message.id)
      |> noreply()
    else
      _error ->
        socket |> put_flash(:error, "Something went wrong") |> close_modal() |> noreply()
    end
  end

  @impl true
  def handle_info({:confirm_event, "delete"}, %{assigns: %{job: job}} = socket) do
    from(m in ClientMessage, where: m.job_id == ^job.id and is_nil(m.deleted_at))
    |> Repo.update_all(set: [deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)])

    socket
    |> close_modal()
    |> push_redirect(to: Routes.inbox_path(socket, :index), replace: true)
    |> noreply()
  end

  defp add_message(message_changeset, %{} = job, recipients, user) do
    Messages.add_message_to_job(message_changeset, job, recipients, user) |> Repo.transaction()
  end

  defp add_message(message_changeset, _job, recipients, user) do
    Messages.add_message_to_client(message_changeset, recipients, user) |> Repo.transaction()
  end
end
