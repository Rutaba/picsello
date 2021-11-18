defmodule PicselloWeb.GalleryLive.UpdatePreviewPhoto do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Galleries

  @impl true
  # def update(data, socket) do

  def update(%{id: _id, gallery: gallery} = data, socket) do
      IO.puts "_______________"
    IO.inspect data
    {:ok,
     socket
    #  |> assign(:, url)
     |> assign(:gallery, gallery)
     |> assign_gallery_changeset()}
  end

  @impl true
  def handle_event("validate", %{"gallery" => %{"name" => name}}, socket) do
    socket
    |> assign_gallery_changeset(%{name: name})
    |> noreply
  end

  @impl true
  def handle_event("save", %{"gallery" => %{"name" => name}}, socket) do
    %{assigns: %{gallery: gallery}} = socket
    {:ok, gallery} = Galleries.update_gallery(gallery, %{name: name})

    socket
    |> assign(:gallery, gallery)
    |> noreply
  end

  @impl true
  def handle_event("reset", _params, socket) do
    %{assigns: %{gallery: gallery}} = socket

    socket
    |> assign(:gallery, Galleries.reset_gallery_name(gallery))
    |> assign_gallery_changeset()
    |> noreply
  end

  defp assign_gallery_changeset(%{assigns: %{gallery: gallery}} = socket),
    do: socket |> assign(:changeset, Galleries.change_gallery(gallery))

  defp assign_gallery_changeset(%{assigns: %{gallery: gallery}} = socket, attrs),
    do: socket |> assign(:changeset, Galleries.change_gallery(gallery, attrs))
end
