defmodule Picsello.Photos do
  @moduledoc "context module for uploaded photos"

  import Ecto.Query, only: [from: 2]

  alias Picsello.{
    Repo,
    Cart.Digital,
    Galleries.Watermark,
    Galleries.Photo,
    Galleries.Workers.PhotoStorage
  }

  @gallery_icon "/images/gallery-icon.svg"
  @card_blank "/images/card_blank.png"

  def preview_url(%{watermarked: _} = photo, opts) do
    url = preview_url(photo)

    with true <- url == @gallery_icon,
         true <- Keyword.get(opts, :blank, false) do
      @card_blank
    else
      _ -> url
    end
  end

  def preview_url(url, opts) do
    preview_url(%{watermarked: false, preview_url: url}, opts)
  end

  def preview_url(%{watermarked: true, watermarked_preview_url: "" <> path}),
    do: path_to_url(path)

  def preview_url(%{watermarked: _, preview_url: "" <> path}), do: path_to_url(path)

  def preview_url(_), do: @gallery_icon

  def original_url(%{original_url: path}), do: path_to_url(path)

  def watermarked_query do
    watermark =
      from(watermark in Watermark,
        group_by: watermark.gallery_id,
        select: watermark.gallery_id
      )

    digital =
      from(digital in Digital,
        join: order in assoc(digital, :order),
        join: photo in assoc(digital, :photo),
        where: not is_nil(order.placed_at),
        group_by: [photo.gallery_id, photo.id],
        select: %{gallery_id: photo.gallery_id, photo_id: photo.id}
      )

    from(photo in Photo,
      left_join: watermarked in subquery(watermark),
      on: watermarked.gallery_id == photo.gallery_id,
      left_join: digital in subquery(digital),
      on: digital.gallery_id == photo.gallery_id and digital.photo_id == photo.id,
      select: %{
        photo
        | watermarked: not is_nil(watermarked.gallery_id) and is_nil(digital.photo_id)
      }
    )
  end

  @doc """
  Gets a single photo by id.

  Returns nil if the Photo does not exist.

  ## Examples

      iex> get(123)
      %Photo{}

      iex> get(44545)
      nil

  """
  def get(id), do: Repo.get(watermarked_query(), id)

  def toggle_liked(id) when is_number(id) do
    {1, [photo]} =
      from(photo in Photo,
        where: photo.id == ^id,
        update: [set: [client_liked: not photo.client_liked]],
        select: photo
      )
      |> Repo.update_all([])

    {:ok, photo}
  end

  defdelegate path_to_url(path), to: PhotoStorage
end
