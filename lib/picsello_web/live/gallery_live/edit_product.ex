defmodule PicselloWeb.GalleryLive.EditProduct do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.Galleries
  alias Picsello.Galleries.Photo
  alias Picsello.Galleries.PhotoProcessing.GalleryUploadProgress
  alias Picsello.Galleries.PhotoProcessing.ProcessingManager
  alias Picsello.Galleries.Workers.PhotoStorage

  @impl true
  def handle_event("close", _, socket) do
    send(self(), :close_upload_popup)

    socket |> noreply()
  end

 #@impl true
  #def handle_event("update-print-type", _, %{} = socket) do
 # end

end
