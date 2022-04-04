defmodule PicselloWeb.GalleryLive.Photos.Photo do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Phoenix.LiveView.JS
  alias Picsello.Galleries

  @impl true
  def mount(socket) do
    socket
    |> assign(:preview_photo_id, nil)
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

  defp js_like_click(js \\ %JS{}, id, target) do
    js
    |> JS.push("like", target: target, value: %{id: id})
    |> JS.toggle(to: "#photo-#{id}-liked")
    |> JS.toggle(to: "#photo-#{id}-to-like")
  end
end
