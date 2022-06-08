defmodule PicselloWeb.GalleryLive.Photos.UploadError do
  @moduledoc false
  use PicselloWeb, :live_component

  @string_length 35

  @impl true
  def mount(socket) do
    socket
    |> ok()
  end

  @impl true
  def handle_event(
        "delete_photo",
        %{"index" => index, "delete_from" => delete_from},
        %{assigns: assigns} = socket
      ) do
    delete_from = String.to_atom(delete_from)
    index = String.to_integer(index)
    {_, pending_photos} = assigns[delete_from] |> List.pop_at(index)

    delete_broadcast(index, delete_from)

    socket
    |> assign(delete_from, pending_photos)
    |> then(fn %{assigns: %{invalid_photos: invalid_photos, pending_photos: pending_photos}} =
                 socket ->
      if Enum.empty?(pending_photos ++ invalid_photos) do
        socket |> close_modal()
      else
        socket
      end
    end)
    |> noreply()
  end

  @impl true
  def handle_event("delete_all_photos", _, socket) do
    delete_broadcast([], "delete_all")

    socket
    |> close_modal()
    |> noreply()
  end

  @impl true
  def handle_event(
        "upload_pending_photos",
        %{"index" => index},
        %{assigns: %{invalid_photos: invalid_photos, pending_photos: pending_photos}} = socket
      ) do
    index = String.to_integer(index)
    {_, pending_entries} = pending_photos |> List.pop_at(index)

    upload_broadcast(index)

    if Enum.empty?(pending_entries ++ invalid_photos) do
      socket |> close_modal()
    else
      socket
    end
    |> assign(:pending_photos, pending_entries)
    |> noreply()
  end

  @impl true
  def handle_event("upload_all_pending_photos", _, socket) do
    upload_broadcast([])

    socket
    |> close_modal()
    |> noreply()
  end

  @impl true
  def handle_event("close", _, socket) do
    socket
    |> close_modal()
    |> noreply()
  end

  defp upload_broadcast(index) do
    Phoenix.PubSub.broadcast(
      Picsello.PubSub,
      "upload_pending_photos",
      {:upload_pending_photos, %{index: index}}
    )
  end

  defp delete_broadcast(index, delete_from) do
    Phoenix.PubSub.broadcast(
      Picsello.PubSub,
      "delete_photos",
      {:delete_photos, %{index: index, delete_from: delete_from}}
    )
  end

  defp truncate_name(%{client_name: client_name, client_type: client_type}) do
    if String.length(client_name) > @string_length do
      String.slice(client_name, 0..@string_length) <> "..." <> String.slice(client_type, 6..15)
    else
      client_name
    end
  end

  defp error_type(assigns) do
    ~H"""
    <div class="pl-4">
      <%= cond do %>
      <%= @invalid_count > 0 && @pending_count == 0 -> %>
        It looks like some of your photos failed because they’re over our photo size limit. We accept photos up to
        <span class="font-bold">100MB </span>
        in size. Please reduce the file size of these photos and reupload.

      <% @invalid_count == 0 && @pending_count > 0 -> %>
        We can only upload
        <span class="font-bold">1,500 photos at a time</span>
        , so some of your photos are still in the upload queue. You can retry uploading these photos below.

      <% true -> %>
        It looks like some of your photos failed because they’re over our photo size limit. We accept photos up to
        <span class="font-bold">100MB </span>in size. Please reduce the file size of these photos and reupload.<br>
        <br>
        We can only upload
        <span class="font-bold">1,500 photos at a time</span>
        , so some of your photos are still in the upload queue. You can retry uploading these photos below.
      <% end %>
    </div>
    """
  end

  defp errors(assigns) do
    ~H"""
      <div class="uploadEntry px-14 grid grid-cols-5 pb-4 items-center">
        <p class="col-span-3 max-w-md">
        <%= truncate_name(@entry) %>
        </p>
        <div class="flex gap-x-4 grid-cols-1 photoUploadingIsFailed items-center">
          <%= render_slot(@inner_block) %>
        </div>
        <button phx-target={@target} phx-click="delete_photo" phx-value-index={@index} phx-value-delete_from={@delete_from}
              aria-label="remove" class="justify-self-end grid-cols-1 cursor-pointer">
          <.icon name="remove-icon" class="w-3.5 h-3.5 ml-1 text-base-250"/>
        </button>
      </div>
    """
  end
end
