defmodule PicselloWeb.GalleryLive.ProductPreview do
  use PicselloWeb, live_view: [layout: "live_client"]
  alias Picsello.Galleries
  alias Picsello.Galleries.Workers.PhotoStorage
  alias Picsello.Galleries.Workers.PositionNormalizer
  alias Picsello.Galleries.ProductPreview
  alias Picsello.Repo
  import Ecto.Changeset
  require Logger

  @per_page 12

  @impl true
  def mount(params, _session, socket) do
    prdct_id = params["product_id"]
    prdct_id = is_binary(prdct_id) && String.to_integer(prdct_id) || prdct_id
    preview = Repo.get_by(ProductPreview, %{:product_id => prdct_id})
      |> Repo.preload([:photo])

    if preview == nil do
      Logger.error("not found row with product_id: #{prdct_id} in product_previews table")
      {:ok, redirect(socket, to: "/")}
    end

    url = preview.photo.original_url || nil

    {:ok,
      socket
        |> assign(:preview, path(url))
        |> assign(:photo_id, nil)
        |> assign(:changeset, changeset(%{},[:photo_id]))}
  end

  def changeset(data, prop) do
    cast(%Picsello.Galleries.ProductPreview{}, data, prop)
      |> validate_required([:photo_id])
  end

  @impl true
  def handle_event("set_preview", data, socket) do
    name = data["preview-url"]
    photo_id = data["photo_id"] || nil
    chngst = changeset(%{photo_id: photo_id, product_id: 777},[:photo_id, :product_id])
      |> validate_required([:photo_id])

    socket
      |> assign(:preview, path(name))
      |> assign(:photo_id, photo_id)
      |> assign(:product_id, data["product_id"])
      |> assign(:changeset, chngst)
      |> push_event("reload_grid", %{})
      |> noreply
  end

  def handle_event("save", data, socket) do
    photo_id = data["product_preview"]["photo_id"]
    product_id = data["product_preview"]["product_id"]
    photo_id = is_binary(photo_id) && String.to_integer(photo_id) || photo_id
    fields = %{photo_id: photo_id, product_id: product_id}

    case Repo.get_by(ProductPreview, %{:product_id => product_id}) do
      nil -> Logger.error("not found product_preview row with id #{product_id}")
      %Picsello.Galleries.ProductPreview{} = result ->
        result
          |> cast(fields, [:photo_id, :product_id])
          |> Repo.insert_or_update()
    end

    {:noreply, socket |> push_event("reload_grid", %{})}
  end

  def handle_event(
    "update_photo_position",
    %{"photo_id" => photo_id, "type" => type, "args" => args},
    %{assigns: %{gallery: %{id: gallery_id}}} = socket
  ) do
    Galleries.update_gallery_photo_position(
      gallery_id,
      photo_id |> String.to_integer(),
      type,
      args
    )

    PositionNormalizer.normalize(gallery_id)

    noreply(socket)
  end

  @impl true
  def handle_params(%{"id" => id, "product_id" => product_id}, _, socket) do
    gallery = Galleries.get_gallery!(id)
    product_id =
      is_binary(product_id) && String.to_integer(product_id) || product_id

    if Repo.get_by(ProductPreview, %{:product_id => product_id}) == nil do
      {:noreply, redirect(socket, to: "/")}
    else
      socket
        |> assign(:gallery, gallery)
        |> assign(:product_id, product_id)
        |> assign(:page, 0)
        |> assign(:update_mode, "append")
        |> assign(:favorites_filter, false)
        |> assign(:favorites_count, Galleries.gallery_favorites_count(gallery))
        |> assign_photos()
        |> noreply()
    end
  end

  def handle_cover_progress(:cover_photo, entry, %{assigns: assigns} = socket) do
    if entry.done? do
      {:ok, gallery} =
        Galleries.update_gallery(assigns.gallery, %{
          cover_photo_id: entry.uuid,
          cover_photo_aspect_ratio: 1
        })

      {:noreply, socket |> assign(:gallery, gallery)}
    else
      {:noreply, socket}
    end
  end

  defp assign_photos(
    %{
      assigns: %{
        gallery: %{id: id},
        page: page,
        favorites_filter: filter
      }
    } = socket
  ) do

    assign(socket,
      photos: Galleries.get_gallery_photos(id, @per_page, page, only_favorites: filter)
    )
  end

  def path(nil), do: "/images/card_blank.png"
  def path(url), do: PhotoStorage.path_to_url(url)
end
