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
      order_by: [a.is_finals, a.is_proofing, a.position],
      select_merge: %{thumbnail_photo: thumbnail_photo},
      preload: :orders
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
    do:
      Multi.new()
      |> Multi.insert(:album, Album.create_changeset(params))
      |> sort_albums_alphabetically()
      |> Repo.transaction()

  def insert_album_with_selected_photos(params, selected_photos) do
    Multi.new()
    |> Multi.insert(:album, change_album(%Album{}, params))
    |> Multi.update_all(
      :photos,
      fn %{album: album} ->
        from(p in Photo, where: p.id in ^selected_photos, update: [set: [album_id: ^album.id]])
      end,
      []
    )
    |> sort_albums_alphabetically()
    |> Repo.transaction()
  end

  @doc """
  Update album
  """
  def update_album(album, params \\ %{}) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:album, Album.update_changeset(album, params))
    |> sort_albums_alphabetically()
    |> Repo.transaction()
  end

  defp now(), do: DateTime.utc_now() |> DateTime.truncate(:second)

  def save_thumbnail(album, photo), do: album |> Album.update_thumbnail(photo) |> Repo.update()

  def remove_album_thumbnail(ids) do
    from(album in Album,
      where: album.thumbnail_photo_id in ^ids,
      update: [set: [thumbnail_photo_id: nil]]
    )
  end

  def set_album_hash(%Album{client_link_hash: nil} = album) do
    album
    |> Album.update_changeset(%{client_link_hash: UUID.uuid4()})
    |> Repo.update!()
  end

  def set_album_hash(%Album{} = album), do: album

  def get_album_by_hash!(hash), do: Repo.get_by!(Album, client_link_hash: hash)

  def album_password_change(attrs \\ %{}) do
    Album.password_changeset(%Album{}, attrs)
  end

  def create_multiple(folders, gallery_id) do
    folders
    |> Enum.reduce(Multi.new(), fn folder, multi ->
      multi
      |> Multi.insert(
        folder,
        Album.create_changeset(%{
          set_password: false,
          gallery_id: gallery_id,
          name: folder_name(folder)
        })
      )
    end)
    |> Repo.transaction()
  end

  def sort_albums_alphabetically(multi) do
    Ecto.Multi.run(
      multi,
      :write,
      fn _repo, %{album: album} ->
        albums =
          from(a in Album, where: a.gallery_id == ^album.gallery_id, order_by: a.name)
          |> Repo.all()

        albums =
          Enum.with_index(albums, fn album, position ->
            album
            |> Ecto.Changeset.change(%{position: position + 1.0, updated_at: now()})
            |> Repo.update!()
          end)

        {:ok, albums}
      end
    )
  end

  def sort_albums_alphabetically_by_gallery_id(gallery_id) do
    albums =
      from(a in Album, where: a.gallery_id == ^gallery_id, order_by: a.name)
      |> Repo.all()

    Enum.with_index(albums, fn album, position ->
      album
      |> Album.update_changeset(%{position: position + 1})
      |> Repo.update!()
    end)
  end

  @separator "-dsp-"
  def folder_name(folder) do
    [_ | name] = String.split(folder, @separator)
    Enum.join(name)
  end
end
