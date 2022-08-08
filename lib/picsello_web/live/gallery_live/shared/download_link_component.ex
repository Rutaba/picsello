defmodule PicselloWeb.GalleryLive.Shared.DownloadLinkComponent do
  @moduledoc """
    a link to either kick off the packing job, or
    a notice that the packing is in process,
    or a link to the packed zip
  """

  use PicselloWeb, :live_component
  alias Picsello.Orders

  @impl true
  def update(%{status: _status} = assigns, socket) do
    socket |> assign(assigns) |> ok()
  end

  def update(%{order: order} = assigns, socket) do
    Task.start(__MODULE__, :check_status, [self(), order])
    socket |> assign(assigns) |> assign(status: :loading) |> ok()
  end

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :class, fn -> "" end)

    ~H"""
    <div class={"flex items-center justify-center font-medium font-client text-base-300 bg-base-100 border border-base-300 min-w-[12rem]
                hover:text-base-100 hover:bg-base-300
                w-full #{@class}"}>
      <%= case @status do %>
        <% :loading -> %>
          <p class="p-2 text-base-225">Checking...</p>
        <% :uploading -> %>
          <p class="p-2 text-base-225">Preparing Download</p>
        <% {:ready, url} -> %>
          <a href={url} class="flex items-center justify-center w-full h-full p-2">
            Download photos

            <.icon name="forth" class="ml-2 h-3 w-2 stroke-current stroke-[3px]" />
          </a>
      <% end %>
    </div>
    """
  end

  def check_status(pid, order) do
    status =
      case Orders.pack_url(order) do
        {:ok, url} ->
          {:ready, url}

        _ ->
          unless(uploading?(order), do: Orders.pack(order))
          :uploading
      end

    send_update(pid, __MODULE__, status: status, id: order.id)
  end

  def update_path(order, path) do
    send_update(__MODULE__,
      id: order.id,
      status: {:ready, Picsello.Galleries.Workers.PhotoStorage.path_to_url(path)}
    )
  end

  defdelegate uploading?(order), to: Picsello.Workers.PackDigitals, as: :executing?
end
