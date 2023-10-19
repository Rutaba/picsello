defmodule PicselloWeb.GalleryLive.Photos.CloudError do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Phoenix.PubSub
  alias Picsello.Photos

  import PicselloWeb.GalleryLive.Shared, only: [truncate_name: 2, start_photo_processing: 2]

  @string_length 35

  @impl true
  def mount(socket) do
    socket
    |> assign(:string_length, @string_length)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="uploadPopup {@toggle}" id="photo-upload-component">
      <div class="flex flex-col items-center justify-center gap-8 UploadOverallStatus">
        <div class="w-full">
          <div class="flex items-center justify-between w-full px-12 pb-4">
            <p class="font-bold text-2xl">Retry Upload</p>
            <a phx-click="close" phx-target={@myself} class="cursor-pointer">
              <.icon name="close-x" class="w-4 h-4 stroke-current stroke-2"/>
            </a>
          </div>

          <div class="bg-orange-inbox-400 rounded-lg mx-12 py-2">
              <div class="flex justify-center items-center mx-4">
                  <.icon name="warning-orange", class="w-10 h-10 stroke-[4px]" />
                  <.error_type id="error_type" />
              </div>
          </div>
        </div>

        <div class="uploadEntry grid grid-cols-5 w-full px-12">
          <div class="grid-cols-1 col-span-3">
            <span class="error text-xs text-center rounded py-1 px-2 items-center cursor-default">
              <%= Enum.count(@invalid_preview_photos) %> <%= ngettext("photo", "photos", Enum.count(@invalid_preview_photos)) %> failed
            </span>
          </div>
          <div class="grid-cols-2">
            <span phx-target={@myself} phx-click="upload_invalid_previews" class="retry text-xs text-center rounded py-1 px-7 cursor-pointer items-center">
              Retry all?
            </span>
          </div>
          <div class="grid-cols-3 justify-center">
            <.action_button name="Delete all?" {assigns} action="delete_photos" class="border-solid border border-base-250 rounded" />
          </div>
        </div>

        <div class="uploadingList__wrapper bg-base-200/30">
          <%= Enum.map(@invalid_preview_photos, fn photo -> %>
            <div class="uploadEntry grid grid-cols-5 pb-4 items-center px-14">
              <p class="max-w-md overflow-hidden col-span-2">
                <%= truncate_name(photo.name, @string_length) %>
              </p>
              <div class="items-center gap-x-1 lg:gap-x-4 md:gap-x-4 grid-cols-1">
                <p class="error btn items-center">Failed to process</p>
              </div>
              <.action_button name="Retry" {assigns} attrs={[phx_value_id: photo.id]} action="upload_invalid_previews" />
              <.action_button name="Delete" {assigns} attrs={[phx_value_id: photo.id]} action="delete_photos" />
            </div>
          <% end) %>
        </div>
      </div>
      <button phx-click="close" phx-target={@myself} aria-label="canncel" class="bg-black text-white mr-12 mt-5 py-3 px-8 float-right rounded-lg border">
        Close
      </button>
    </div>
    """
  end

  defp action_button(assigns) do
    assigns = Enum.into(assigns, %{class: "", attrs: []})

    ~H"""
    <span phx-target={@myself} phx-click={@action} {@attrs} class={"text-base-300 font-bold text-xs text-center py-1 px-6 cursor-pointer items-center #{@class}"}>
      <%= @name %>
    </span>
    """
  end

  defp error_type(assigns) do
    ~H"""
    <div class="pl-4">
      It looks like some of your photos are stuck in middle of processing to generate preview or watermark versions.
      You can retry processing from here or delete all to select them again from your system
    </div>
    """
  end

  @impl true
  def handle_event(
        "delete_photos",
        params,
        %{assigns: %{gallery: gallery, invalid_preview_photos: invalid_preview_photos}} = socket
      ) do
    invalid_preview_photos = invalid_preview_photos |> get_invalid_preview_photos(params)
    Photos.update_invalid_preview_photos(invalid_preview_photos)

    error_broadcast(gallery.id)

    socket
    |> push_event("remove_items", %{"ids" => Enum.map(invalid_preview_photos, & &1.id)})
    |> close_modal()
    |> noreply()
  end

  @impl true
  def handle_event(
        "upload_invalid_previews",
        params,
        %{assigns: %{gallery: gallery, invalid_preview_photos: invalid_preview_photos}} = socket
      ) do
    invalid_preview_photos = get_invalid_preview_photos(invalid_preview_photos, params)

    Photos.update_invalid_preview_photos(
      invalid_preview_photos,
      updated_at: DateTime.utc_now()
    )

    Enum.each(invalid_preview_photos, &start_photo_processing(&1, gallery))

    error_broadcast(gallery.id)

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

  defp get_invalid_preview_photos(invalid_preview_photos, %{"id" => id}),
    do: [Enum.find(invalid_preview_photos, &(to_string(&1.id) == id))]

  defp get_invalid_preview_photos(invalid_preview_photos, _params), do: invalid_preview_photos

  defp error_broadcast(gallery_id),
    do: PubSub.broadcast(Picsello.PubSub, "invalid_preview:#{gallery_id}", :invalid_preview)
end
