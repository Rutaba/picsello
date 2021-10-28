defmodule Picsello.Galleries do
  @moduledoc """
  The Galleries context.
  """

  import Ecto.Query, warn: false
  alias Picsello.Repo

  alias Picsello.Galleries.{Gallery, Photo}

  @doc """
  Returns the list of galleries.

  ## Examples

      iex> list_galleries()
      [%Gallery{}, ...]

  """
  def list_galleries do
    Repo.all(Gallery)
  end

  @doc """
  Gets a single gallery.

  Raises `Ecto.NoResultsError` if the Gallery does not exist.

  ## Examples

      iex> get_gallery!(123)
      %Gallery{}

      iex> get_gallery!(456)
      ** (Ecto.NoResultsError)

  """
  def get_gallery!(id), do: Repo.get!(Gallery, id)

  @doc """
  Gets a single gallery by hash parameter.

  Returns nil if the Gallery does not exist.

  ## Examples

      iex> get_gallery_by_hash("validhash")
      %Gallery{}

      iex> get_gallery!("wronghash")
      nil

  """
  @spec get_gallery_by_hash(hash :: binary) :: %Gallery{} | nil
  def get_gallery_by_hash(hash) do
    Gallery
    |> where(client_link_hash: ^hash)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Gets single gallery by hash, with relations populated (cover_photo)
  """
  def get_detailed_gallery_by_hash(hash) do
    Repo.preload(get_gallery_by_hash(hash), [:cover_photo])
  end

  @doc """
  Gets paginated photos by gallery id

  Optional options:
    * :only_favorites. If set to `true`, then only liked photos will be returned. Defaults to `false`

  """
  @spec get_gallery_photos(id :: integer, per_page :: integer, page :: integer, opts :: keyword) ::
          list(Photo)
  def get_gallery_photos(id, per_page, page, opts \\ []) do
    only_favorites = Keyword.get(opts, :only_favorites, false)

    select_opts =
      if(only_favorites, do: [client_liked: true], else: []) |> Keyword.merge(gallery_id: id)

    offset = per_page * page

    Photo
    |> where(^select_opts)
    |> order_by(asc: :position)
    |> offset(^offset)
    |> limit(^per_page)
    |> Repo.all()
  end

  @doc """
  Creates a gallery.

  ## Examples

      iex> create_gallery(%{field: value})
      {:ok, %Gallery{}}

      iex> create_gallery(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_gallery(attrs \\ %{}) do
    %Gallery{}
    |> Gallery.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a gallery.

  ## Examples

      iex> update_gallery(gallery, %{field: new_value})
      {:ok, %Gallery{}}

      iex> update_gallery(gallery, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_gallery(%Gallery{} = gallery, attrs) do
    gallery
    |> Gallery.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a gallery.

  ## Examples

      iex> delete_gallery(gallery)
      {:ok, %Gallery{}}

      iex> delete_gallery(gallery)
      {:error, %Ecto.Changeset{}}

  """
  def delete_gallery(%Gallery{} = gallery) do
    Repo.delete(gallery)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking gallery changes.

  ## Examples

      iex> change_gallery(gallery)
      %Ecto.Changeset{data: %Gallery{}}

  """
  def change_gallery(%Gallery{} = gallery, attrs \\ %{}) do
    Gallery.update_changeset(gallery, attrs)
  end

  @doc """
  Loads the gallery photos.

  ## Examples

      iex> load_gallery_photos(gallery, "all")
      [
        %Photo{},
        %Photo{},
        %Photo{}
      ]
  """
  def load_gallery_photos(%Gallery{} = gallery, type \\ "all") do
    load_gallery_photos_by_type(gallery, type)
  end

  defp load_gallery_photos_by_type(gallery, "all") do
    Photo
    |> where(gallery_id: ^gallery.id)
    |> Repo.all()
  end

  defp load_gallery_photos_by_type(gallery, "favorites") do
    Photo
    |> where(gallery_id: ^gallery.id, client_liked: true)
    |> Repo.all()
  end

  defp load_gallery_photos_by_type(_, _), do: []

  @doc """
  Loads the number of favorite photos from the gallery

  ## Examples

      iex> gallery_favorites_count(gallery)
      5
  """
  def gallery_favorites_count(%Gallery{} = gallery) do
    Photo
    |> where(gallery_id: ^gallery.id, client_liked: true)
    |> Repo.aggregate(:count, [])
  end

  @doc """
  Creates a photo.

  ## Examples

      iex> create_photo(%{field: value})
      {:ok, %Photo{}}

      iex> create_photo(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_photo(%{} = attrs) do
    attrs
    |> Photo.create_changeset()
    |> Repo.insert()
  end

  @doc """
  Gets a single photo by id.

  Returns nil if the Photo does not exist.

  ## Examples

      iex> get_photo(123)
      %Photo{}

      iex> get_photo(44545)
      nil

  """
  def get_photo(id), do: Repo.get(Photo, id)

  @doc """
  Marks a photo as liked/unliked.

  ## Examples

      iex> mark_photo_as_liked(%Photo{client_liked: false})
      {:ok, %Photo{client_liked: true}}

      iex> mark_photo_as_liked(%Photo{client_liked: true})
      {:ok, %Photo{client_liked: false}}

  """
  def mark_photo_as_liked(%Photo{client_liked: client_liked} = photo) do
    photo
    |> Photo.update_changeset(%{client_liked: !client_liked})
    |> Repo.update()
  end

  @doc """
  Normalizes photos positions within a gallery
  """
  def normalize_gallery_photo_positions(gallery_id) do
    Ecto.Adapters.SQL.query(
      Repo,
      """
        WITH ranks AS (
          SELECT id, RANK() OVER (ORDER BY position) AS pos
          FROM photos
          WHERE gallery_id = $1::integer
        )
        UPDATE photos p
        SET position = r.pos
        FROM ranks r
        WHERE p.gallery_id = $1::integer
          AND p.id = r.id
      """,
      [gallery_id]
    )
  end

  @doc """
    Changes photo position within a gallery updating the only row
  """
  def update_gallery_photo_position(gallery_id, photo_id, "between", [first_id, second_id]) do
    Ecto.Adapters.SQL.query(
      Repo,
      """
        WITH newpos AS (
          SELECT avg(position) AS pos
          FROM photos
          WHERE gallery_id = $1::integer
            AND id in ($3::integer, $4::integer)
        )
        UPDATE photos
        SET position = newpos.pos
        FROM newpos
        WHERE id = $2::integer
          AND gallery_id = $1::integer
      """,
      [gallery_id, photo_id, first_id, second_id]
    )
  end

  def update_gallery_photo_position(gallery_id, photo_id, "before", [another_id]) do
    Ecto.Adapters.SQL.query(
      Repo,
      """
        WITH newpos AS (
          SELECT position - 1 AS pos
          FROM photos
          WHERE gallery_id = $1::integer
            AND id = $3::integer
        )
        UPDATE photos
        SET position = newpos.pos
        FROM newpos
        WHERE id = $2::integer
          AND gallery_id = $1::integer
      """,
      [gallery_id, photo_id, another_id]
    )
  end

  def update_gallery_photo_position(gallery_id, photo_id, "after", [another_id]) do
    Ecto.Adapters.SQL.query(
      Repo,
      """
        WITH newpos AS (
          SELECT position + 1 AS pos
          FROM photos
          WHERE gallery_id = $1::integer
            AND id = $3::integer
        )
        UPDATE photos
        SET position = newpos.pos
        FROM newpos
        WHERE id = $2::integer
          AND gallery_id = $1::integer
      """,
      [gallery_id, photo_id, another_id]
    )
  end

  def gallery_current_status(nil), do: :none_created
  def gallery_current_status(%Gallery{status: "expired"}), do: :deactivated
  def gallery_current_status(%Gallery{total_count: nil}), do: :upload_in_progress

  def gallery_current_status(%Gallery{} = gallery) do
    gallery = Repo.preload(gallery, [:photos])
    has_watermark = false

    gallery
    |> Map.get(:photos, [])
    |> Enum.any?(fn photo ->
      is_nil(photo.aspect_ratio) ||
        is_nil(photo.preview_url) ||
        (has_watermark && is_nil(photo.watermarked_url))
    end)
    |> then(fn
      false -> :ready
      true -> :upload_in_progress
    end)
  end
end
