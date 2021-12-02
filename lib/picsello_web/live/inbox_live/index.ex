defmodule PicselloWeb.InboxLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Job, Repo, ClientMessage}
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Inbox")
    |> assign(:current_thread, nil)
    |> assign_threads()
    |> ok()
  end

  @impl true
  def handle_params(%{"id" => thread_id}, _uri, socket) do
    socket
    |> assign_current_thread(String.to_integer(thread_id))
    |> noreply()
  end

  @impl true
  def handle_params(_params, _uri, socket), do: socket |> noreply()

  @impl true
  def render(assigns) do
    ~H"""
    <div class={classes("bg-blue-planning-100", %{"hidden sm:block" => @current_thread})}><h1 class="px-6 py-8 text-3xl font-bold center-container">Inbox</h1></div>
    <div class="center-container py-6">
      <h2 class={classes("font-semibold text-2xl px-6", %{"hidden sm:block" => @current_thread})}>Messages</h2>
      <hr class={classes("mt-6", %{"hidden sm:block" => @current_thread})} />

      <div class="flex h-[calc(100vh-18rem)]">
        <div class={classes("w-full sm:w-1/3 overflow-y-auto flex-shrink-0", %{"hidden sm:block" => @current_thread})}>
          <%= for thread <- @threads do %>
            <.thread_card {thread} selected={@current_thread && thread.id == @current_thread.id} />
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
        <div class="text-2xl line-clamp-1"><%= @title %></div>
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
      <div class="w-full sm:overflow-y-auto">
        <div class="sticky top-0 bg-white px-6 sm:px-2 py-2 flex shadow-sm sm:shadow-none">
          <.live_link to={Routes.inbox_path(@socket, :index)} class="sm:hidden pt-2 pr-4">
            <.icon name="left-arrow" class="w-6 h-6" />
          </.live_link>
          <div>
            <div class="sm:font-semibold text-2xl line-clamp-1"><%= @title %></div>
            <div class="sm:hidden line-clamp-1 font-semibold py-0.5"><%= @subtitle %></div>
          </div>
        </div>
        <div class="flex flex-col p-6">
          <%= for message <- @messages do %>
            <div {testid("thread-message")} class={classes("m-2 max-w-sm sm:max-w-xl", %{"self-end" => message.outbound, "self-start" => !message.outbound})}>
              <div class={classes("mb-2 flex justify-between items-end", %{"flex-row-reverse" => !message.outbound})}>
                <div class="text-xs"><%= message.date %></div>
                <div class="mx-1"><%= message.sender %> wrote:</div>
              </div>
              <div class="border rounded p-6"><%= message.body %></div>
            </div>
          <% end %>
        </div>
        <div phx-hook="ScrollIntoView" id={"thread-#{@id}"} />
      </div>
    """
  end

  @impl true
  def handle_event("open-thread", %{"id" => id}, socket) do
    socket
    |> push_patch(to: Routes.inbox_path(socket, :show, id))
    |> noreply()
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

  defp assign_current_thread(%{assigns: %{current_user: current_user}} = socket, thread_id) do
    job = Job.for_user(current_user) |> Repo.get!(thread_id) |> Repo.preload(:client)

    thread_messages =
      from(message in ClientMessage,
        where: message.job_id == ^job.id,
        order_by: [asc: message.inserted_at]
      )
      |> Repo.all()
      |> Enum.map(fn message ->
        sender = if message.outbound, do: "You", else: job.client.name

        %{
          body: message.body_text,
          date: strftime(current_user.time_zone, message.inserted_at, "%a %b %-d, %-I:%-M %p"),
          outbound: message.outbound,
          sender: sender
        }
      end)

    socket
    |> assign(:current_thread, %{
      id: thread_id,
      messages: thread_messages,
      title: job.client.name,
      subtitle: Job.name(job)
    })
  end
end
