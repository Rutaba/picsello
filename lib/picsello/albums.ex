defmodule Picsello.Albums do
  @moduledoc """
  The Albums context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Picsello.Repo
  alias Picsello.Galleries.Album
  alias Picsello.Galleries.Photo

  @doc """
  Gets a single album.

  Raises `Ecto.NoResultsError` if the Gallery does not exist.

  ## Examples

      iex> get_album!(123)
      %Album{}

      iex> get_album!(456)
      ** (Ecto.NoResultsError)

  """
  def get_album!(id), do: Repo.get!(Album, id)

  @doc """
  Gets alubms by gallery id.

  Return [] if the albums does not exist.

  ## Examples

      iex> get_albums_by_gallery_id(gallery_id)
      [%Album{}]
  """
  def get_albums_by_gallery_id(gallery_id) do
    from(a in Album,
      left_join: thumbnail_photo in subquery(Picsello.Photos.watermarked_query()),
      on: a.thumbnail_photo_id == thumbnail_photo.id,
      where: a.gallery_id == ^gallery_id,
      order_by: a.id,
      select_merge: %{thumbnail_photo: thumbnail_photo}
    )
    |> Repo.all()
    |> Enum.map(fn
      %{thumbnail_photo: %{id: nil}} = album -> %{album | thumbnail_photo: nil}
      album -> album
    end)
  end

  def change_album(%Album{} = album, params \\ %{}) do
    album |> Album.update_changeset(params)
  end

  @doc """
  Insert album
  """
  def insert_album(params),
    do: Album.create_changeset(params) |> Repo.insert()

  def insert_album_with_selected(params, selected_photos) do
    Multi.new()
    |> Multi.insert(:album, change_album(%Album{}, params))
    |> Multi.update_all(
      :photos,
      fn %{album: album} ->
        from(p in Photo, where: p.id in ^selected_photos, update: [set: [album_id: ^album.id]])
      end,
      []
    )
    |> Repo.transaction()
  end

  @doc """
  Update album
  """
  def update_album(album, params \\ %{}),
    do: album |> Album.update_changeset(params) |> Repo.update()

  def save_thumbnail(album, photo), do: album |> Album.update_thumbnail(photo) |> Repo.update()

  def remove_album_thumbnail(ids) do
    from(album in Album,
      where: album.thumbnail_photo_id in ^ids,
      update: [set: [thumbnail_photo_id: nil]]
    )
  end
end
