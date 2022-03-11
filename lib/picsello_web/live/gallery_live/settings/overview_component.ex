defmodule PicselloWeb.GalleryLive.Settings.OverviewComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  import PicselloWeb.GalleryLive.Show, only: [presign_cover_entry: 2, handle_cover_progress: 3]

  @upload_options [
    accept: ~w(.jpg .jpeg .png image/jpeg image/png),
    max_entries: 1,
    max_file_size: 104_857_600,
    auto_upload: true,
    external: &presign_cover_entry/2,
    progress: &handle_cover_progress/3
  ]
  @bucket Application.compile_env(:picsello, :photo_storage_bucket)

  @impl true
  def update(%{id: id, gallery: gallery}, socket) do
    {
      :ok,
      socket
      |> assign(:id, id)
      |> assign(:gallery, gallery)
      |> assign(:upload_bucket, @bucket)
      |> assign(:cover_photo_processing, false)
      |> allow_upload(:cover_photo, @upload_options)
    }
  end
end
