defmodule PicselloWeb.InboxLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Job, Repo, ClientMessage, Messages, Notifiers.ClientNotifier}
  import Ecto.Query
  import Picsello.Galleries.Workers.PhotoStorage, only: [path_to_url: 1]

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Inbox")
    |> assign(:current_thread, nil)
    |> assign_threads()
    |> assign_unread()
    |> subscribe_inbound_messages()
    |> assign(:tabs, tabs_list(socket))
    |> assign(:tab_active, "all")
    |> ok()
  end

  @impl true
  def handle_params(%{"id" => thread_id, "type" => type}, _uri, socket) do
    socket
    |> assign_unread()
    |> assign_current_thread(thread_id, type)
    |> noreply()
  end

  @impl true
  def handle_params(_params, _uri, socket), do: socket |> noreply()

  @impl true
  def render(assigns) do
    ~H"""
    <div class={classes(%{"hidden sm:block" => @current_thread})} {intro(@current_user, "intro_inbox")}><h1 class="px-6 py-10 text-4xl font-bold center-container" {testid("inbox-title")}>Inbox</h1></div>
    <div class={classes("center-container pb-6", %{"pt-0" => @current_thread})}>
      <div class={classes("flex bg-gray-100 py-6 items-center mb-6 px-4 rounded-lg", %{"hidden sm:flex" => @current_thread})}>
        <h2 class="font-bold text-2xl">Viewing all messages</h2>
        <div class="flex ml-auto gap-3">
          <%= for {true, %{name: name, action: action, concise_name: concise_name}} <- @tabs do %>
            <button class={classes("border rounded-lg border-blue-planning-300 text-blue-planning-300 py-1 px-4", %{"text-white bg-blue-planning-300" => @tab_active === concise_name, "hover:opacity-100" => @tab_active !== concise_name})} type="button" phx-click={action} phx-value-tab={concise_name}><%= name %></button>
          <% end %>
        </div>
      </div>

      <div class="flex sm:h-[calc(100vh-18rem)]">
        <div class={classes("border-t w-full sm:w-1/3 overflow-y-auto flex-shrink-0", %{"hidden sm:block" => @current_thread, "hidden" => Enum.empty?(@threads)})}>
          <%= if @current_thread && !Enum.find(@threads, & &1.id == @current_thread.id) do %>
            <.thread_card {@current_thread} message={nil} date={nil} unread={false} selected={true} />
          <% end %>
          <%= for thread <- @threads do %>
            <.thread_card {thread} unread={Enum.member?(@unread_job_ids, thread.id)} selected={@current_thread && thread.id == @current_thread.id} />
          <% end %>
        </div>
        <%= cond do %>
          <% @current_thread != nil -> %>
            <.current_thread {@current_thread} socket={@socket} />
          <% Enum.empty?(@threads) -> %>
            <div class="flex w-full items-center justify-center p-6 border">
              <div class="flex items-center flex-col text-blue-planning-300 text-xl">
                <.icon name="envelope" class="text-blue-planning-300 w-20 h-32" />
                <p>You don’t have any new messages.</p>
                <p>Go to a job or lead to send a new message. <.tooltip id="inbox-lead" content="You haven’t sent any booking proposals or client communications yet - once you have, those conversations will all be logged here, and you’ll be able to send and receive messages to your clients. " /></p>
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
    <div {testid("thread-card")} {scroll_to_thread(@selected, @id)} phx-click="open-thread" phx-value-id={@id} phx-value-type={@type} class={classes("flex justify-between py-6 border-b pl-2 p-8 hover:bg-gray-100 hover:text-black cursor-pointer", %{"bg-blue-planning-300 rounded-lg text-white" => @selected})}>
      <div class="px-4">
        <div class="flex items-center">
          <div class="font-bold	text-2xl line-clamp-1"><%= @title %></div>
          <%= if @unread do %>
            <span {testid("new-badge")} class="mx-4 px-2 py-0.5 text-xs rounded bg-orange-inbox-300 text-white">New</span>
          <% end %>
        </div>
        <div class="line-clamp-1 font-semibold py-0.5"><%= @subtitle %></div>
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
              <.icon name="camera-check" class="text-blue-planning-300 w-6 h-6 mr-2" />
              <%= if @is_lead do %>
                <.live_link to={Routes.job_path(@socket, :leads, @id)} class="rounded-lg bg-gray-100 py-1 px-4 text-blue-planning-300">
                  View lead
                </.live_link>
              <% else %>
                <.live_link to={Routes.job_path(@socket, :jobs, @id)} class="flex gap-2 items-center rounded-lg bg-gray-100 py-1 px-4 text-blue-planning-300">
                  View job
                  <.icon name="forth" class="stroke-2 h-3 w-2 mt-1" />
                </.live_link>
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
              <div class={classes("mb-3 flex justify-between items-end", %{"flex-row-reverse" => !message.outbound})}>
                <div class="mx-1">
                  <%= unless message.same_sender do %>
                    <%= message.sender %> wrote:
                  <% end %>
                </div>
              </div>

              <div class="relative border rounded p-4">
                <%= if message.unread do %>
                  <div class="absolute bg-orange-inbox-300 rounded-full -top-2 -right-2 w-4 h-4"></div>
                <% end %>
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

              <div class={classes("flex items-center font-bold text-xl px-4 py-2", %{"rounded-t-lg" => message.collapsed_sections, "rounded-lg" => !message.collapsed_sections, "bg-blue-planning-300 text-white" => message.outbound, "bg-gray-300" => !message.outbound})} phx-click="collapse-section" phx-value-id={message.id}>
                <%= message.subject %>
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
                  <div class="ml-auto text-blue-planning-300 underline cursor-pointer" phx-click="show-cc" phx-value-id={message.id}>
                    <%= if(message.show_cc?) do %>
                      Hide Cc/Bcc
                    <% else %>
                      Show Cc/Bcc
                    <% end %>
                  </div>
                </div>
                <div class="flex flex-col relative border rounded-b-lg p-6">
                  <%= if message.unread do %>
                    <div class="absolute bg-orange-inbox-300 rounded-full -top-2 -right-2 w-4 h-4"></div>
                  <% end %>
                  <span class="whitespace-pre-line"><%= raw message.body %></span>
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
        <div class="sticky bottom-0 bg-white flex flex-col p-6 bg-white sm:flex-row-reverse">
          <button class="btn-primary" phx-click="compose-message">
            Reply
          </button>
        </div>
      </div>
    """
  end

  def scroll_to_message(message) do
    if message.scroll do
      %{phx_hook: "ScrollIntoView", id: "message-#{message.id}"}
    else
      %{}
    end
  end

  def scroll_to_thread(selected, id) do
    if selected do
      %{phx_hook: "ScrollIntoView", id: "thread-#{id}"}
    else
      %{}
    end
  end

  @impl true
  def handle_event("open-thread", %{"id" => id, "type" => type}, socket) do
    socket
    |> push_patch(to: Routes.inbox_path(socket, :show, id, type))
    |> noreply()
  end

  @impl true
  def handle_event("change-tab", %{"tab" => tab}, socket) do
    socket
    |> assign(:tab_active, tab)
    |> assign_tab_data(tab)
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
  def handle_event("collapse-section", %{"id" => id}, socket) do
    new_messages =
      Enum.map(socket.assigns.current_thread.messages, fn entry ->
        if entry.id == String.to_integer(id) do
          collapsed_sections = Map.get(entry, :collapsed_sections, false)
          Map.update!(entry, :collapsed_sections, fn _ -> !collapsed_sections end)
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
        "compose-message",
        %{},
        %{assigns: %{job: job, current_user: current_user}} = socket
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

  defp assign_threads(%{assigns: %{current_user: current_user}} = socket, type \\ :all) do
    message_query =
      case type do
        :job ->
          job_query = Job.for_user(current_user)

          from(message in ClientMessage,
            where: not is_nil(message.job_id),
            distinct: message.job_id,
            join: jobs in subquery(job_query),
            on: jobs.id == message.job_id,
            where: is_nil(message.deleted_at),
            order_by: [desc: message.inserted_at]
          )

        :client ->
          client_message_receipent_query = Picsello.ClientMessageRecipient.for_user(current_user)

          from(message in ClientMessage,
            where: is_nil(message.job_id),
            where: is_nil(message.deleted_at),
            join: client_message_receipents in subquery(client_message_receipent_query),
            on: client_message_receipents.client_message_id == message.id,
            distinct: client_message_receipents.client_id,
            order_by: [desc: message.inserted_at]
          )

        :all ->
          job_query = Job.for_user(current_user)

          from(message in ClientMessage,
            distinct: message.job_id,
            join: jobs in subquery(job_query),
            on: jobs.id == message.job_id,
            where: is_nil(message.deleted_at),
            order_by: [desc: message.inserted_at]
          )
      end

    threads =
      from(message in subquery(message_query), order_by: [desc: message.inserted_at])
      |> Repo.all()
      |> Repo.preload(client_message_recipients: [:client], job: [:client])
      |> Enum.map(fn message ->
        body = if(message.body_text, do: message.body_text, else: message.body_html)
        type = check_and_assign_type(message.job_id)

        title =
          if message.job,
            do: message.job.client.name,
            else: hd(message.client_message_recipients).client.name

        subtitle = if message.job, do: Job.name(message.job), else: "CLIENTS SUBTITLE"

        %{
          id: message.job_id || hd(message.client_message_recipients).client_id,
          title: title,
          subtitle: subtitle,
          message: body,
          type: type,
          date: strftime(current_user.time_zone, message.inserted_at, "%a, %B %d, %I:%M:%S %p")
        }
      end)

    socket
    |> assign(:threads, threads)
  end

  defp assign_unread(%{assigns: %{current_user: current_user}} = socket) do
    query =
      Job.for_user(current_user)
      |> ClientMessage.unread_messages()

    unread_messages_by_job =
      from(message in query,
        distinct: message.job_id,
        order_by: [asc: message.inserted_at],
        select: {message.job_id, message.id}
      )
      |> Repo.all()
      |> Map.new()

    socket
    |> assign(:unread_message_ids, Map.values(unread_messages_by_job))
    |> assign(:unread_job_ids, Map.keys(unread_messages_by_job))
  end

  defp assign_current_thread(
         %{assigns: %{current_user: current_user, unread_message_ids: unread_message_ids}} =
           socket,
         thread_id,
         type \\ "job",
         message_id_to_scroll \\ nil
       ) do
    job =
      if type == "job" do
        Job.for_user(current_user)
        |> Repo.get!(thread_id)
        |> Repo.preload([:client, :job_status])
      end

    client_message_recipients =
      if type == "client" do
        Picsello.ClientMessageRecipient.for_user(current_user)
        |> where(client_id: ^thread_id)
        |> preload(:client)
        |> limit(1)
        |> Repo.one()
      end

    client_messages =
      case type do
        "job" ->
          from(message in ClientMessage,
            where: message.job_id == ^job.id and is_nil(message.deleted_at),
            order_by: [asc: message.inserted_at],
            preload: [:client_message_recipients, job: [:client]]
          )
          |> Repo.all()

        "client" ->
          from(message in ClientMessage,
            where:
              message.id == ^client_message_recipients.client_message_id and
                is_nil(message.deleted_at),
            order_by: [asc: message.inserted_at],
            preload: [client_message_recipients: [:client]]
          )
          |> Repo.all()
      end

    thread_messages =
      client_messages
      |> Enum.with_index()
      |> Enum.reduce(%{last: nil, messages: []}, fn {message, index},
                                                    %{last: last, messages: messages} ->
        {sender, receiver} =
          case type do
            "job" ->
              sender = if message.outbound, do: "You", else: message.job.client.name
              receiver = if message.outbound, do: message.job.client.email, else: "You"
              {sender, receiver}

            "client" ->
              sender =
                if message.outbound,
                  do: "You",
                  else: hd(message.client_message_recipients).client.name

              receiver =
                if message.outbound,
                  do: hd(message.client_message_recipients).client.email,
                  else: "You"

              {sender, receiver}
          end

        same_sender = last && last.outbound == message.outbound
        body = if message.body_text, do: message.body_text, else: message.body_html
        cc = assign_message_recipients(message, :cc)
        bcc = assign_message_recipients(message, :bcc)

        read_at =
          if message.read_at,
            do: strftime(current_user.time_zone, message.read_at, "%a, %B %d, %I:%M:%S %p"),
            else: nil

        %{
          last: message,
          messages:
            messages ++
              [
                %{
                  id: message.id,
                  body: body,
                  date:
                    strftime(current_user.time_zone, message.inserted_at, "%a %b %-d, %-I:%0M %p"),
                  outbound: message.outbound,
                  sender: sender,
                  receiver: receiver,
                  cc: cc,
                  bcc: bcc,
                  subject: message.subject,
                  same_sender: same_sender,
                  is_first_unread: Enum.member?(unread_message_ids, message.id),
                  scroll:
                    message.id == message_id_to_scroll || index == length(client_messages) - 1,
                  unread: message.read_at == nil,
                  client_message_attachments: message.client_message_attachments,
                  show_cc?: false,
                  collapsed_sections: true,
                  read_at: read_at
                }
              ]
        }
      end)
      |> Map.get(:messages)

    id = if type == "job", do: job.id, else: client_message_recipients.client_id
    title = if type == "job", do: job.client.name, else: client_message_recipients.client.name
    subtitle = if type == "job", do: Job.name(job), else: "Client Subtitle"
    is_lead = if type == "job", do: job.job_status.is_lead, else: false

    socket
    |> assign(:current_thread, %{
      id: id,
      messages: thread_messages,
      title: title,
      subtitle: subtitle,
      is_lead: is_lead
    })
    |> assign(:job, job)
    |> mark_current_thread_as_read()
  end

  defp assign_message_recipients(%{client_message_recipients: client_message_recipients}, type) do
    client_message_recipients
    |> Enum.filter(fn x -> x.recipient_type == type end)
    |> case do
      [] ->
        nil

      list ->
        Enum.map_join(list, ";", fn x ->
          Repo.get(Picsello.Client, x.client_id).email
        end)
    end
  end

  defp check_and_assign_type(nil), do: :client
  defp check_and_assign_type(_job_id), do: :job

  defp tabs_list(_socket) do
    [
      {true,
       %{
         name: "All",
         concise_name: "all",
         action: "change-tab"
       }},
      {true,
       %{
         name: "Jobs/Leads",
         concise_name: "jobs-leads",
         action: "change-tab"
       }},
      {true,
       %{
         name: "Clients",
         concise_name: "clients",
         action: "change-tab"
       }},
      {true,
       %{
         name: "Marketing",
         concise_name: "marketing",
         action: "change-tab"
       }}
    ]
  end

  defp assign_tab_data(socket, tab) do
    case tab do
      "all" ->
        socket
        |> assign_threads()

      "jobs-leads" ->
        socket
        |> assign_threads(:job)
        |> assign(:current_thread, nil)

      "clients" ->
        socket
        |> assign_threads(:client)
        |> assign(:current_thread, nil)

      "marketing" ->
        socket |> assign_threads()

      _ ->
        socket
    end
    |> assign(:current_thread, nil)
  end

  defp mark_current_thread_as_read(%{assigns: %{current_thread: %{id: id}}} = socket) do
    if connected?(socket) do
      from(m in ClientMessage, where: m.job_id == ^id and is_nil(m.read_at))
      |> Repo.update_all(set: [read_at: DateTime.utc_now() |> DateTime.truncate(:second)])
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

  def handle_info({:inbound_messages, message}, socket) do
    socket
    |> assign_threads()
    |> assign_unread()
    |> then(fn socket ->
      if socket.assigns.current_thread do
        assign_current_thread(socket, socket.assigns.current_thread.id, message.id)
      else
        socket
      end
    end)
    |> noreply()
  end

  def handle_info(
        {:message_composed, message_changeset, recipients},
        %{assigns: %{job: job, current_user: user}} = socket
      ) do
    with {:ok, %{client_message: message, client_message_recipients: _}} <-
           Messages.add_message_to_job(message_changeset, job, recipients, user)
           |> Repo.transaction(),
         {:ok, _email} <- ClientNotifier.deliver_email(message, recipients) do
      socket
      |> close_modal()
      |> assign_threads()
      |> assign_current_thread(job.id, message.id)
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
end
