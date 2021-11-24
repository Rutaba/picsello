defmodule PicselloWeb.GalleryLive.PreviewComponent do
  use PicselloWeb, :live_component
  alias Picsello.Galleries
  alias Picsello.Galleries.Workers.PhotoStorage
  alias Picsello.Galleries.Photo
  alias Picsello.Galleries.ProductPreview
  alias Picsello.Repo
  import Ecto.Changeset
  require Logger

  def update(%{preview: nil, product_id: prdct_id} = params, socket) do
    preview = Repo.get_by(ProductPreview, %{:product_id => prdct_id})
      |> Repo.preload([:photo])

    data = Map.put(params, :preview, preview.photo.original_url)
    data = Map.put(data, :photo, preview.photo)
    set_assign(data, socket )
  end

  def update(%{product_id: nil} = params, socket), do: set_assign(params, socket)
  def update(params, socket), do: set_assign(params, socket)

  def set_assign(%{preview: url, photo_id: photo_id, product_id: prdct_id} = d, socket) do
    {:ok, socket
      |> assign(:preview, path(url))
      |> assign(:photo_id, photo_id)
      |> assign(:product_id, prdct_id)
      |> assign(:changeset, changeset(%{photo_id: photo_id, product_id: prdct_id},[:photo_id]))}
  end

  def changeset(data, prop) do
    cast(%Picsello.Galleries.ProductPreview{}, data, prop)
      |> validate_required([:photo_id])
  end

  def handle_event("set_preview", data, socket) do
    socket
      |> assign(:preview, data["preview"])
      |> assign(:photo_id, data["photo_id"])
      |> assign(:product_id, data["product_id"])
      |> assign(:changeset, changeset(%{photo_id: data["photo_id"]},[:photo_id]))
      |> noreply
  end

  def path(nil), do: "/images/card_blank.png"
  def path(url), do: PhotoStorage.path_to_url(url)
end
