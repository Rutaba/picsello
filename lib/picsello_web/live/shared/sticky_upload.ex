defmodule PicselloWeb.Shared.StickyUpload do
  @moduledoc """
    Helper functions to use the Sticky upload component
  """
  use PicselloWeb, :live_component

  import PicselloWeb.Router.Helpers, only: [static_path: 2]

  alias PicselloWeb.GalleryLive.Photos.Upload
  alias Phoenix.PubSub

  @impl true
  def update(assigns, socket) do
    user_id = assigns.current_user.id

    gallery_ids =
      user_id
      |> clean_data()
      |> PicselloWeb.UploaderCache.get()
      |> subscribe_upload()

    socket
    |> assign(Enum.into(assigns, %{exclude_gallery_id: true}))
    |> assign(gallery_ids: gallery_ids)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= for gallery_id <- @gallery_ids do %>
        <%= if @exclude_gallery_id && @exclude_gallery_id != gallery_id do %>
          <div class="hidden">
            <%= live_render(@socket, Upload, id: "upload-button-#{gallery_id}", class: "hidden", session: %{"gallery_id" => gallery_id, "album_id" => nil, "view" => "add_button"}, sticky: true) %>
            <%= live_render(@socket, Upload, id: "drag-drop-#{gallery_id}", class: "hidden", session: %{"gallery_id" => gallery_id, "album_id" => nil, "view" => "drag_drop"}, sticky: true) %>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  def gallery_top_banner(assigns) do
    assigns = assigns |> Enum.into(%{class: ""})

    ~H"""
    <div class={classes("flex justify-center py-2 #{@class}", %{"hidden" => @accumulated_progress == 100 || @accumulated_progress == 0})}>
      <div class="flex items-start">
        <img class="w-8 pr-2" src={static_path(PicselloWeb.Endpoint, "/images/gallery-icon-white.svg")} />
        <%= ngettext("1 gallery is", "%{count} galleries are", @galleries_count) %> uploading - <%= @accumulated_progress %>%
      </div>
      <div class="flex pl-2 items-center">
        <div class={"w-52 h-2 rounded-lg bg-[#0094ad]"}>
          <div class="h-full rounded-lg bg-white" style={"width: #{@accumulated_progress}%"}></div>
        </div>
      </div>
    </div>
    """
  end

  defp subscribe_upload(upload_data) do
    gallery_ids = upload_data |> Enum.map(fn {_, gallery_id, _} -> gallery_id end)

    gallery_ids
    |> Enum.each(fn gallery_id ->
      PubSub.subscribe(Picsello.PubSub, "galleries_progress:#{gallery_id}")
      PubSub.subscribe(Picsello.PubSub, "photo_upload_completed:#{gallery_id}")
    end)

    gallery_ids
  end

  defp clean_data(user_id) do
    PicselloWeb.UploaderCache.delete(user_id)
    user_id
  end

  def sticky_upload(%{current_user: nil} = assigns), do: ~H""

  def sticky_upload(assigns) do
    ~H"""
    <.live_component module={__MODULE__} id={assigns[:id] || "sticky_upload"} {assigns} />
    """
  end
end
