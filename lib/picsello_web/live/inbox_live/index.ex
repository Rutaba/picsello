defmodule PicselloWeb.InboxLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Job, Repo, ClientMessage}
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Inbox")
    |> assign_threads()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-blue-planning-100"><h1 class="px-6 py-8 text-3xl font-bold center-container">Inbox</h1></div>
    <div class="center-container p-6">
      <h2 class="font-semibold text-2xl">Messages</h2>
      <hr class="mt-6" />


      <div class="flex h-[calc(100vh-18rem)]">
        <div class="w-full sm:w-1/3 overflow-y-auto">
          <%= for thread <- @threads do %>
            <.thread_card {thread} />
          <% end %>
        </div>
        <div class="hidden sm:flex w-2/3 bg-orange-inbox-100 items-center justify-center">
          <div class="flex items-center">
            <.icon name="envelope" class="text-orange-inbox-300 w-20 h-32" />
            <p class="ml-4 text-orange-inbox-300 text-xl w-48">Select a message to your left</p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp thread_card(assigns) do
    ~H"""
    <div {testid("thread-card")} class="flex justify-between py-6 border-b pl-2 p-8 hover:bg-gray-100 cursor-pointer">
      <div>
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
          title: message.job.client.name,
          subtitle: Job.name(message.job),
          message: message.body_text,
          date: strftime(current_user.time_zone, message.inserted_at, "%-m/%-d/%y")
        }
      end)

    socket
    |> assign(:threads, threads)
  end
end
