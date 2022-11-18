defmodule PicselloWeb.GalleryLive.Shared.DownloadLinkComponent do
  @moduledoc """
    a link to either kick off the packing job, or
    a notice that the packing is in process,
    or a link to the packed zip
  """

  use PicselloWeb, :live_component

  require Logger

  alias Picsello.Pack

  @impl true
  def update(%{status: _status} = assigns, socket) do
    socket |> assign(assigns) |> ok()
  end

  def update(%{packable: packable} = assigns, socket) do
    Task.start(__MODULE__, :check_status, [self(), packable])
    socket |> assign(assigns) |> assign(status: :loading) |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={"flex items-center justify-center font-medium font-client text-base-300 bg-base-100 border border-base-300 min-w-[12rem]
                hover:text-base-100 hover:bg-base-300
                #{@class}"}>
      <%= case @status do %>
        <% :loading -> %>
          <p class="p-2 text-base-225">Checking...</p>
        <% :uploading -> %>
          <p class="p-2 text-base-225">Preparing Download</p>
        <% {:ready, url} -> %>
          <a href={url} class="flex items-center justify-center w-full h-full p-2">
            <%= render_slot(@inner_block) %>
          </a>
      <% end %>
    </div>
    """
  end

  def download_link(assigns) do
    assigns = assign_new(assigns, :class, fn -> "" end)

    ~H"""
    <.live_component class={@class} module={__MODULE__} id={@packable.id} packable={@packable}><%= render_slot(@inner_block) %></.live_component>
    """
  end

  def check_status(pid, packable) do
    status =
      case Pack.url(packable) do
        {:ok, url} ->
          {:ready, url}

        _ ->
          Logger.info("[Enqueue] PackDigitals from download_link_component line 56")
          enqueue(packable)
          :uploading
      end

    send_update(pid, __MODULE__, status: status, id: packable.id)
  end

  def update_status(id, status), do: send_update(__MODULE__, id: id, status: status)
  defdelegate enqueue(packable), to: Picsello.Workers.PackDigitals
end
