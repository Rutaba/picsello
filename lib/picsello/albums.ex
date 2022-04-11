defmodule Picsello.Albums do
  @moduledoc """
  The Albums context.
  """

  import Ecto.Query, warn: false

  alias Picsello.Repo
  alias Picsello.Galleries.Album

  @doc """
  Returns the list of albums.

  ## Examples

      iex> list_albums()
      [%Album{}, ...]

  """
  def list_albums do
    Repo.all(Album)
  end

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
      where: a.gallery_id == ^gallery_id,
      order_by: a.id
    )
    |> Repo.all()
  end

  @doc """
  Insert album
  """
  def insert_album(params),
    do: Album.create_changeset(params) |> Repo.insert()

  @doc """
  Update album
  """
  def update_album(album, params \\ %{}),
    do: album |> Album.update_changeset(params) |> Repo.update()

  def remove_album_thumbnail(photos) do
    urls = Enum.map(photos, & &1.preview_url)

    from(gp in Album,
      where: gp.thumbnail_url in ^urls,
      update: [set: [thumbnail_url: nil]]
    )
  end
end
