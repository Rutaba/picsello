defmodule PicselloWeb.GalleryLive.Photos.Photo do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Phoenix.LiveView.JS
  alias Picsello.Galleries

  @impl true
  def mount(socket) do
    socket
    |> assign(:preview_photo_id, nil)
    |> assign(:url, Routes.static_path(PicselloWeb.Endpoint, "/images/gallery-icon.svg"))
    |> ok
  end

  @impl true
  def handle_event("like", %{"id" => id}, socket) do
    {:ok, _} =
      Galleries.get_photo(id)
      |> Galleries.mark_photo_as_liked()

    socket |> noreply()
  end

  @impl true
  def handle_event("click", _, %{assigns: %{photo: photo}} = socket) do
    send(self(), {:photo_click, photo})

    socket
    |> noreply()
  end

  defp toggle_border(js \\ %JS{}, id, is_gallery_category_page) do
    if is_gallery_category_page do
      js
      |> JS.dispatch("click", to: "#photo-#{id} > img")
      |> JS.add_class("item-border", to: "#item-#{id}")
    else
      js |> JS.dispatch("click", to: "#photo-#{id} > img")
    end
  end

  defp js_like_click(js \\ %JS{}, id, target) do
    js
    |> JS.push("like", target: target, value: %{id: id})
    |> JS.toggle(to: "#photo-#{id}-liked")
    |> JS.toggle(to: "#photo-#{id}-to-like")
  end

  defp meatball(album, id) do
    if album do
      [
        %{
          id: "photo-thumbnail-#{id}",
          event: "set_album_thumbnail_popup",
          title: "Set as album thumbnail"
        },
        %{id: "photo-remove-#{id}", event: "remove_from_album_popup", title: "Remove from album"}
      ]
    else
      []
    end ++
      [
        %{id: "photo-preview-#{id}", event: "photo_preview_pop", title: "Set as product preview"},
        %{
          id: "photo-download-#{id}",
          event: "photo_download_pop",
          title: "Download photo",
          class: "hidden"
        }
      ]
  end

  defp photo(%{target: false} = assigns) do
    ~H"""
    <img phx-click="click" phx-value-preview={@preview} phx-value-preview_photo_id={@photo_id} src={@url} class="relative" />
    """
  end

  defp photo(assigns) do
    ~H"""
    <img phx-click="click" phx-target={@target} phx-value-preview={@preview} phx-value-preview_photo_id={@photo_id} src={@url} class="relative" />
    """
  end

  defp ul(assigns) do
    ~H"""
    <ul class="absolute hidden bg-white rounded-md toggle-content meatballsdropdown w-40 overflow-visible">
      <%= for li <- @entries do %>
      <li class={"flex #{Map.get(li, :class, nil)} items-center hover:bg-blue-planning-100 hover:rounded-md"}>
        <div id={li.id} class="hover-drop-down" phx-click={li.event} phx-value-photo_id={@id}>
          <%= li.title %>
        </div>
      </li>
      <% end %>
    </ul>
    """
  end

  defp actions(assigns) do
    ~H"""
    <div id={@id} class={"absolute #{@class}"} phx-click={@event} phx-value-photo_id={@photo_id}>
      <.icon name={@icon} class="h-6 text-gray-200 w-7"/>
    </div>
    """
  end
end
