defmodule PicselloWeb.GalleryLive.PreviewComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  require Logger
  import Ecto.Changeset
  alias Picsello.Galleries.Workers.PhotoStorage
  alias Picsello.Galleries.ProductPreview
  alias Picsello.Repo

  def update(%{preview: nil, product_id: product_id} = params, socket) do
    preview =
      Repo.get_by(ProductPreview, %{:product_id => product_id})
      |> Repo.preload([:photo])

    data = Map.put(params, :preview, preview.photo.preview_url)
    data = Map.put(data, :photo, preview.photo)
    set_assign(data, socket)
  end

  def update(%{product_id: nil} = params, socket), do: set_assign(params, socket)
  def update(params, socket), do: set_assign(params, socket)

  def set_assign(%{preview: url, photo_id: photo_id, product_id: product_id}, socket) do
    {:ok,
     socket
     |> assign(:preview, path(url))
     |> assign(:photo_id, photo_id)
     |> assign(:product_id, product_id)
     |> assign(:changeset, changeset(%{photo_id: photo_id, product_id: product_id}, [:photo_id]))}
  end

  def changeset(data, prop) do
    cast(%Picsello.Galleries.ProductPreview{}, data, prop)
    |> validate_required([:photo_id])
  end

  def path(nil), do: "/images/card_blank.png"
  def path(url), do: PhotoStorage.path_to_url(url)
end
