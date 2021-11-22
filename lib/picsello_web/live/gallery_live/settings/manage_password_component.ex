defmodule PicselloWeb.GalleryLive.Settings.ManagePasswordComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Galleries

  @impl true
  def update(%{id: id, gallery: gallery}, socket) do
    {:ok,
     socket
     |> assign(:visibility, false)
     |> assign(:id, id)
     |> assign(:gallery, gallery)}
  end

  @impl true
  def handle_event("toggle_visibility", _, %{assigns: %{visibility: visibility}} = socket) do
    socket
    |> assign(:visibility, !visibility)
    |> noreply
  end

  @impl true
  def handle_event("regenerate", _params, %{assigns: %{gallery: gallery}} = socket) do
    socket
    |> assign(:gallery, Galleries.regenerate_gallery_password(gallery))
    |> noreply
  end
end
