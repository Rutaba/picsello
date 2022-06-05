defmodule PicselloWeb.GalleryLive.Photos.UploadError do
  @moduledoc false
  use PicselloWeb, :live_component

  @string_length 50

  @impl true
  def mount(socket) do
    socket
    |> ok()
  end

  @impl true
  def handle_event("delete_photo", %{"index" => index, "delete_from" => delete_from}, %{assigns: assigns} = socket) do
    delete_from = String.to_atom(delete_from)
    index = String.to_integer(index)
    {_, pending_photos} = assigns[delete_from] |> List.pop_at(index)

    delete_broadcast(index, delete_from)

    socket
    |> assign(delete_from, pending_photos)
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
  def handle_event("upload_pending_photos", %{"index" => index}, %{assigns: %{invalid_photos: invalid_photos, pending_photos: pending_photos}} = socket) do
    index = String.to_integer(index)
    {_, pending_entries} = pending_photos |> List.pop_at(index)

    upload_broadcast(index)

    if Enum.empty?(pending_entries ++ invalid_photos)  do
      delete_broadcast([], nil)
      socket
      |> close_modal()
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
    delete_broadcast([], nil)
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
end
