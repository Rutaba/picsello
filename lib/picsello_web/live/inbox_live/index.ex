defmodule PicselloWeb.InboxLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Job, Repo, ClientMessage, Notifiers.ClientNotifier}
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Inbox")
    |> assign(:current_thread, nil)
    |> assign_threads()
    |> assign_unread()
    |> subscribe_inbound_messages()
    |> ok()
  end

  @impl true
  def handle_params(%{"id" => thread_id}, _uri, socket) do
    socket
    |> assign_unread()
    |> assign_current_thread(thread_id)
    |> noreply()
  end

  @impl true
  def handle_params(_params, _uri, socket), do: socket |> noreply()

  @impl true
  def render(assigns) do
    ~H"""
    <div class={classes("bg-blue-planning-100", %{"hidden sm:block" => @current_thread})}><h1 class="px-6 py-8 text-3xl font-bold center-container">Inbox</h1></div>
    <div class={classes("center-container py-6", %{"pt-0" => @current_thread})}>
      <h2 class={classes("font-semibold text-2xl mb-6 px-6", %{"hidden sm:block sm:mt-6" => @current_thread})}>Messages</h2>

      <div class="flex sm:h-[calc(100vh-18rem)]">
        <div class={classes("border-t w-full sm:w-1/3 overflow-y-auto flex-shrink-0", %{"hidden sm:block" => @current_thread})}>
          <%= for thread <- @threads do %>
            <.thread_card {thread} unread={Enum.member?(@unread_job_ids, thread.id)} selected={@current_thread && thread.id == @current_thread.id} />
          <% end %>
        </div>
        <%= cond do %>
          <% @current_thread != nil -> %>
            <.current_thread {@current_thread} socket={@socket} />
          <% true -> %>
            <div class="hidden sm:flex w-2/3 bg-orange-inbox-100 items-center justify-center">
              <div class="flex items-center">
                <.icon name="envelope" class="text-orange-inbox-300 w-20 h-32" />
                <p class="ml-4 text-orange-inbox-300 text-xl w-48">Select a message to your left</p>
              </div>
            </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp thread_card(assigns) do
    ~H"""
    <div {testid("thread-card")} phx-click="open-thread" phx-value-id={@id} class={classes("flex justify-between py-6 border-b pl-2 p-8 hover:bg-gray-100 cursor-pointer", %{"bg-gray-100" => @selected})}>
      <div class="px-4">
        <div class="flex items-center">
          <div class="text-2xl line-clamp-1"><%= @title %></div>
          <%= if @unread do %>
            <span {testid("new-badge")} class="mx-4 px-2 py-0.5 text-xs rounded bg-blue-planning-200 text-white">New</span>
          <% end %>
        </div>
        <div class="line-clamp-1 font-semibold py-0.5"><%= @subtitle %></div>
        <div class="line-clamp-1"><%= @message %></div>
      </div>
      <div class="relative flex flex-shrink-0">
        <%= @date %>
        <.icon name="forth" class="sm:hidden absolute top-1.5 -right-6 w-4 h-4 stroke-current text-base-300" />
      </div>
    </div>
    """
  end

  defp current_thread(assigns) do
    ~H"""
      <div class="w-full sm:overflow-y-auto sm:border">
        <div class="sticky z-10 top-0 bg-white px-6 sm:px-2 py-2 flex shadow-sm sm:shadow-none">
          <.live_link to={Routes.inbox_path(@socket, :index)} class="sm:hidden pt-2 pr-4">
            <.icon name="left-arrow" class="w-6 h-6" />
          </.live_link>
          <div>
            <div class="sm:font-semibold sm:pb-1 text-2xl line-clamp-1"><%= @title %></div>
            <div class="sm:hidden line-clamp-1 font-semibold py-0.5"><%= @subtitle %></div>
          </div>
        </div>
        <div class="flex flex-col p-6">
          <%= for message <- @messages do %>
            <%= if message.is_first_unread do %>
              <div class="flex items-center my-1">
                <div class="flex-1 h-px bg-orange-inbox-300"></div>
                <div class="text-orange-inbox-300 px-4">new message</div>
                <div class="flex-1 h-px bg-orange-inbox-300"></div>
              </div>
            <% end %>
            <div {testid("thread-message")} {scroll_to_message(message)} class={classes("m-2 max-w-sm sm:max-w-xl", %{"self-end" => message.outbound, "self-start" => !message.outbound})} style="scroll-margin-bottom: 7rem">
              <div class={classes("mb-3 flex justify-between items-end text-base-250", %{"flex-row-reverse" => !message.outbound})}>
                <div class="text-xs"><%= message.date %></div>
                <div class="mx-1">
                  <%= unless message.same_sender do %>
                    <%= message.sender %> wrote:
                  <% end %>
                </div>
              </div>
              <div class="relative border rounded p-6">
                <%= if message.unread do %>
                  <div class="absolute bg-orange-inbox-300 rounded-full -top-2 -right-2 w-4 h-4"></div>
                <% end %>
                <span class="whitespace-pre-line"><%= message.body %></span>
              </div>
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

  @impl true
  def handle_event("open-thread", %{"id" => id}, socket) do
    socket
    |> push_patch(to: Routes.inbox_path(socket, :show, id))
    |> noreply()
  end

  @impl true
  def handle_event("compose-message", %{}, %{assigns: %{job: job}} = socket) do
    socket |> PicselloWeb.ClientMessageComponent.open(%{subject: Job.name(job)}) |> noreply()
  end

  defp assign_threads(%{assigns: %{current_user: current_user}} = socket) do
    job_query = Job.for_user(current_user)

    message_query =
      from(message in ClientMessage,
        distinct: message.job_id,
        join: jobs in subquery(job_query),
        on: jobs.id == message.job_id,
        order_by: [desc: message.inserted_at]
      )

    threads =
      from(message in subquery(message_query), order_by: [desc: message.inserted_at])
      |> Repo.all()
      |> Repo.preload(job: :client)
      |> Enum.map(fn message ->
        %{
          id: message.job_id,
          title: message.job.client.name,
          subtitle: Job.name(message.job),
          message: message.body_text,
          date: strftime(current_user.time_zone, message.inserted_at, "%-m/%-d/%y")
        }
      end)

    socket
    |> assign(:threads, threads)
  end

  defp assign_unread(%{assigns: %{current_user: current_user}} = socket) do
    job_query = Job.for_user(current_user)

    unread_messages_by_job =
      from(message in ClientMessage,
        distinct: message.job_id,
        join: jobs in subquery(job_query),
        on: jobs.id == message.job_id,
        where: is_nil(message.read_at),
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
         message_id_to_scroll \\ nil
       ) do
    job = Job.for_user(current_user) |> Repo.get!(thread_id) |> Repo.preload(:client)

    client_messages =
      from(message in ClientMessage,
        where: message.job_id == ^job.id,
        order_by: [asc: message.inserted_at]
      )
      |> Repo.all()

    thread_messages =
      client_messages
      |> Enum.with_index()
      |> Enum.reduce(%{last: nil, messages: []}, fn {message, index},
                                                    %{last: last, messages: messages} ->
        sender = if message.outbound, do: "You", else: job.client.name
        same_sender = last && last.outbound == message.outbound

        %{
          last: message,
          messages:
            messages ++
              [
                %{
                  id: message.id,
                  body: message.body_text,
                  date:
                    strftime(current_user.time_zone, message.inserted_at, "%a %b %-d, %-I:%-M %p"),
                  outbound: message.outbound,
                  sender: sender,
                  same_sender: same_sender,
                  is_first_unread: Enum.member?(unread_message_ids, message.id),
                  scroll:
                    message.id == message_id_to_scroll || index == length(client_messages) - 1,
                  unread: message.read_at == nil
                }
              ]
        }
      end)
      |> Map.get(:messages)

    socket
    |> assign(:current_thread, %{
      id: job.id,
      messages: thread_messages,
      title: job.client.name,
      subtitle: Job.name(job)
    })
    |> assign(:job, job)
    |> mark_current_thread_as_read()
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
        {:message_composed, message_changeset},
        %{assigns: %{job: job}} = socket
      ) do
    client = job |> Repo.preload(:client) |> Map.get(:client)

    with {:ok, message} <-
           message_changeset
           |> Ecto.Changeset.put_change(:job_id, job.id)
           |> Repo.insert(),
         {:ok, _email} <- ClientNotifier.deliver_email(message, client.email) do
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
end
