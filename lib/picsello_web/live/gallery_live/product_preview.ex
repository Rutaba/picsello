defmodule PicselloWeb.GalleryLive.ProductPreview do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  require Logger
  import Ecto.Changeset
  alias Picsello.Galleries
  alias Picsello.Galleries.Gallery
  alias Picsello.Galleries.ProductPreview
  alias PicselloWeb.GalleryLive.PreviewComponent
  alias Picsello.Repo

  @per_page 12

  @impl true
  def mount(%{"id" => gallery_id, "product_id" => product_id}, _session, socket) do
    gallery = Repo.get_by(Gallery, %{id: gallery_id})
    product_id = (is_binary(product_id) && String.to_integer(product_id)) || product_id

    preview =
      Repo.get_by(ProductPreview, %{:product_id => product_id})
      |> Repo.preload([:photo])

    if nil in [preview, gallery] do
      gallery == nil &&
        Logger.error("not found row with gallery_id: #{gallery_id} in galleries table")

      preview == nil &&
        Logger.error("not found row with product_id: #{product_id} in product_previews table")

      {:ok, redirect(socket, to: "/")}
    else
      url = preview.photo.preview_url || nil

      {:ok,
       socket
       |> assign(:preview, url)
       |> assign(:photo_id, nil)
       |> assign(:changeset, changeset(%{}, [:photo_id]))}
    end
  end

  def changeset(data, prop) do
    cast(%Picsello.Galleries.ProductPreview{}, data, prop)
    |> validate_required([:photo_id])
  end

  @impl true
  def handle_event(
        "set_preview",
        %{
          "photo_id" => photo_id,
          "preview_url" => preview_url,
          "product_id" => product_id
        },
        socket
      ) do
    send_update(PreviewComponent,
      id: :preview_form,
      photo_id: photo_id,
      preview: preview_url,
      product_id: product_id
    )

    socket
    |> noreply
  end

  def handle_event(
        "save",
        %{
          "product_preview" => %{
            "photo_id" => photo_id,
            "product_id" => product_id
          }
        },
        socket
      ) do
    photo_id = (is_binary(photo_id) && String.to_integer(photo_id)) || photo_id
    fields = %{photo_id: photo_id, product_id: product_id}

    case Repo.get_by(ProductPreview, %{:product_id => product_id}) do
      nil ->
        Logger.error("not found product_preview row with id #{product_id}")

      %Picsello.Galleries.ProductPreview{} = result ->
        result
        |> cast(fields, [:photo_id, :product_id])
        |> Repo.insert_or_update()
    end

    {:noreply, socket |> push_event("reload_grid", %{})}
  end

  @impl true
  def handle_params(%{"id" => id, "product_id" => product_id}, _, socket) do
    gallery = Galleries.get_gallery!(id)
    product_id = (is_binary(product_id) && String.to_integer(product_id)) || product_id

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
end
