defmodule PicselloWeb.GalleryLive.SideNavComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Galleries

  @impl true
  def update(%{id: id, gallery: gallery, total_progress: total_progress}, socket) do
    {:ok,
     socket
     |> assign(:id, id)
     |> assign(:total_progress, total_progress || 0)
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

  defp assign_gallery_changeset(%{assigns: %{gallery: gallery}} = socket),
    do: socket |> assign(:changeset, Galleries.change_gallery(gallery))

  defp assign_gallery_changeset(%{assigns: %{gallery: gallery}} = socket, attrs),
    do: socket |> assign(:changeset, Galleries.change_gallery(gallery, attrs))
end
