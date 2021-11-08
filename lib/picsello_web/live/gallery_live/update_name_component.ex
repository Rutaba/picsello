defmodule PicselloWeb.GalleryLive.UpdateNameComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Galleries

  @impl true
  def update(%{id: id, gallery: gallery}, socket) do
    {:ok, 
      socket
      |> assign(:id, id)
      |> assign(:gallery, gallery)
      |> assign(:changeset, Galleries.change_gallery(gallery))
    }
  end

  @impl true
  def handle_event("validate", %{"gallery" => %{"name" => name}}, socket) do
    %{assigns: %{gallery: gallery}} = socket
    
    socket
    |> assign(:changeset, Galleries.change_gallery(gallery, %{name: name}))
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
    {:ok, gallery} = Galleries.reset_gallery_name(gallery)
    
    socket
    |> assign(:gallery, gallery)
    |> assign(:changeset, Galleries.change_gallery(gallery))
    |> noreply
  end
end
