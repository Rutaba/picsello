defmodule Picsello.Galleries do
  @moduledoc """
  The Galleries context.
  """

  import Ecto.Query, warn: false

  alias Picsello.Galleries.{Gallery, Photo, Watermark, SessionToken, GalleryProduct}
  alias Picsello.GalleryProducts
  alias Picsello.Galleries.PhotoProcessing.ProcessingManager
  alias Picsello.Workers.CleanStore
  alias Galleries.PhotoProcessing.ProcessingManager
  alias Galleries.{Gallery, Photo, Watermark, SessionToken, GalleryProduct}
  import Repo.CustomMacros

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
  Returns the list of expired galleries.

  ## Examples

      iex> list_expired_galleries()
      [%Gallery{}, ...]

  """
  def list_expired_galleries do
    Gallery |> where(status: "expired") |> Repo.all()
  end

  @doc """
  Returns the list of soon to be expired galleries.

  ## Examples

      iex> list_soon_to_be_expired_galleries()
      [%Gallery{}, ...]

  """
  def list_soon_to_be_expired_galleries(date) do
    Gallery
    |> where([g], g.expired_at <= ^date)
    |> Repo.all()
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

      iex> get_gallery_by_hash("wronghash")
      nil

  """
  @spec get_gallery_by_hash(hash :: binary) :: %Gallery{} | nil
  def get_gallery_by_hash(hash), do: Repo.get_by(Gallery, client_link_hash: hash)

  @spec get_gallery_by_hash!(hash :: binary) :: %Gallery{}
  def get_gallery_by_hash!(hash), do: Repo.get_by!(Gallery, client_link_hash: hash)

  @doc """
  Gets single gallery by hash, with relations populated (cover_photo)
  """
  def get_detailed_gallery_by_hash(hash) do
    Repo.preload(get_gallery_by_hash(hash), [:cover_photo])
  end

  @doc """
  Gets paginated photos by gallery id

  Optional options:
    * :only_favorites. If set to `true`, then only liked photos will be returned. Defaults to `false`;
    * :offset. Defaults to `per_page * page`.

  """
  @spec get_gallery_photos(id :: integer, per_page :: integer, page :: integer, opts :: keyword) ::
          list(Photo)
  def get_gallery_photos(id, per_page, page, opts \\ []) do
    only_favorites = Keyword.get(opts, :only_favorites, false)
    exclude_album = Keyword.get(opts, :exclude_album, false)

    conditions = dynamic([p], p.gallery_id == ^id)

    conditions =
      if only_favorites do
        dynamic([p], p.client_liked == true and ^conditions)
      else
        conditions
      end

    conditions =
      if exclude_album do
        dynamic([p], is_nil(p.album_id) and ^conditions)
      else
        conditions
      end

    offset = Keyword.get(opts, :offset, per_page * page)

    Photo
    |> where(^conditions)
    |> order_by(asc: :position)
    |> offset(^offset)
    |> limit(^per_page)
    |> Repo.all()
  end

  @spec get_album_photos(
          id :: integer,
          album_id :: integer,
          per_page :: integer,
          page :: integer,
          opts :: keyword
        ) ::
          list(Photo)
  def get_album_photos(id, per_page, page, album_id, opts \\ []) do
    only_favorites = Keyword.get(opts, :only_favorites, false)
    offset = Keyword.get(opts, :offset, per_page * page)

    select_opts =
      if(only_favorites, do: [client_liked: true], else: [])
      |> Keyword.merge(gallery_id: id, album_id: album_id)

    Photo
    |> where(^select_opts)
    |> order_by(asc: :position)
    |> offset(^offset)
    |> limit(^per_page)
    |> Repo.all()
  end

  @spec get_all_album_photos(
          id :: integer,
          album_id :: integer
        ) ::
          list(Photo)
  def get_all_album_photos(id, album_id) do
    Photo
    |> where([p], p.gallery_id == ^id and p.album_id == ^album_id)
    |> order_by(asc: :position)
    |> Repo.all()
  end

  def update_photos_album_id(photo_ids, album_id) do
    Photo
    |> where([p], p.id in ^photo_ids)
    |> Repo.update_all(set: [album_id: album_id])
  end

  def remove_photos_from_album(photo_ids) do
    Photo
    |> where([p], p.id in ^photo_ids)
    |> Repo.update_all(set: [album_id: nil])
  end

  def delete_photos(photo_ids) do
    Photo
    |> where([p], p.id in ^photo_ids)
    |> Repo.delete_all()
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
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:gallery, Gallery.create_changeset(%Gallery{}, attrs))
    |> Ecto.Multi.insert_all(
      :gallery_products,
      GalleryProduct,
      fn %{
           gallery: %{
             id: gallery_id
           }
         } ->
        from(category in (Category.active() |> Category.shown()),
          select: %{
            inserted_at: now(),
            updated_at: now(),
            gallery_id: ^gallery_id,
            category_id: category.id
          }
        )
      end
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{gallery: gallery}} -> {:ok, gallery}
      {:error, :gallery, changeset, _} -> {:error, changeset}
      other -> other
    end
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
  Set the gallery name as the job type.
  """
  def reset_gallery_name(%Gallery{} = gallery) do
    alias Picsello.Job

    name =
      gallery
      |> Repo.preload(:job)
      |> then(fn %{job: job} -> Job.name(job) end)

    gallery
    |> Gallery.update_changeset(%{name: name})
    |> Repo.update!()
  end

  @doc """
  Generates new password for the gallery.
  """
  def regenerate_gallery_password(%Gallery{} = gallery) do
    changeset = Gallery.update_changeset(gallery, %{password: Gallery.generate_password()})

    Ecto.Multi.new()
    |> Ecto.Multi.update(:gallery, changeset)
    |> Ecto.Multi.delete_all(:session_tokens, gallery_session_tokens_query(gallery))
    |> Repo.transaction()
    |> then(fn
      {:ok, %{gallery: gallery}} -> gallery
      {:error, reason} -> reason
    end)
  end

  defp gallery_session_tokens_query(gallery) do
    from(st in SessionToken, where: st.gallery_id == ^gallery.id)
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
    Ecto.Multi.new()
    |> Ecto.Multi.delete_all(:gallery_products, gallery_products_query(gallery))
    |> Ecto.Multi.delete_all(:session_tokens, gallery_session_tokens_query(gallery))
    |> Ecto.Multi.delete_all(:photos, Ecto.assoc(gallery, :photos))
    |> Ecto.Multi.delete_all(:watermark, Ecto.assoc(gallery, :watermark))
    |> Ecto.Multi.delete(:gallery, gallery)
    |> Repo.transaction()
    |> then(fn
      {:ok, %{gallery: gallery}} -> {:ok, gallery}
      {:error, reason} -> reason
    end)

    # Repo.delete(gallery.photos)
    # Repo.delete(gallery)
  end

  defp gallery_products_query(gallery) do
    from(gp in GalleryProduct, where: gp.gallery_id == ^gallery.id)
  end

  defp gallery_products_query(gallery) do
    from(gp in GalleryProduct, where: gp.gallery_id == ^gallery.id)
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

  def set_expire(%Gallery{} = gallery, attrs) do
    gallery
    |> Gallery.expire_changeset(attrs)
    |> Repo.update()
  end

  def set_gallery_hash(%Gallery{client_link_hash: nil} = gallery) do
    gallery
    |> Gallery.client_link_changeset(%{client_link_hash: UUID.uuid4()})
    |> Repo.update!()
  end

  def set_gallery_hash(%Gallery{} = gallery), do: gallery

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
    |> order_by(asc: :position)
    |> Repo.all()
  end

  defp load_gallery_photos_by_type(gallery, "favorites") do
    Photo
    |> where(gallery_id: ^gallery.id, client_liked: true)
    |> order_by(asc: :position)
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
  Updates a photo
  """
  def update_photo(nil, %{} = _attrs), do: []

  def update_photo(%Photo{id: _} = photo, %{} = attrs) do
    photo
    |> Photo.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  updates album_id for multiple photos.
  """
  def update_selected_photos(album_id, selected_photos) do
    from(p in Photo,
      where: p.id in ^selected_photos,
      update: [set: [album_id: ^String.to_integer(album_id)]]
    )
    |> Repo.update_all([])
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
  Removes the photo from DB and all its versions from cloud bucket.
  """
  def delete_photo(%Photo{} = photo) do
    GalleryProducts.check_is_photo_selected_as_preview(photo.id)

    Repo.delete(photo)

    [
      photo.original_url,
      photo.preview_url,
      photo.watermarked_url,
      photo.watermarked_preview_url
    ]
    |> Enum.each(fn path ->
      %{path: path}
      |> CleanStore.new()
      |> Oban.insert()
    end)
  end

  @doc """
  Normalizes photos positions within a gallery
  """
  def normalize_gallery_photo_positions(gallery_id) do
    Ecto.Adapters.SQL.query(
      Repo,
      """
        WITH ranks AS (
          SELECT id, ROW_NUMBER() OVER (ORDER BY position) AS pos
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

  def update_gallery_photo_count(gallery_id) do
    Ecto.Adapters.SQL.query(
      Repo,
      """
        UPDATE galleries
        SET total_count = (SELECT count(*) FROM photos WHERE gallery_id = $1::integer)
        WHERE id = $1::integer;
      """,
      [gallery_id]
    )
  end

  def gallery_current_status(nil), do: :none_created
  def gallery_current_status(%Gallery{status: "expired"}), do: :deactivated

  def gallery_current_status(%Gallery{} = gallery) do
    gallery = Repo.preload(gallery, [:photos])

    gallery
    |> Map.get(:photos, [])
    |> Enum.any?(fn photo ->
      is_nil(photo.aspect_ratio) ||
        is_nil(photo.preview_url)
    end)
    |> then(fn
      false -> :ready
      true -> :upload_in_progress
    end)
  end

  @doc """
  Creates or updates watermark of the gallery.
  And triggers photo watermarking
  """
  def save_gallery_watermark(gallery, watermark_change) do
    gallery
    |> Repo.preload(:watermark)
    |> Gallery.save_watermark(watermark_change)
    |> Repo.update()
    |> tap(fn
      {:ok, gallery} ->
        gallery
        |> Repo.preload([:watermark, :photos])
        |> Map.get(:photos)
        |> Enum.each(&ProcessingManager.update_watermark(&1, gallery.watermark))

      x ->
        x
    end)
  end

  @doc """
  Preloads the watermark of the gallery.
  """
  def load_watermark_in_gallery(%Gallery{} = gallery) do
    Repo.preload(gallery, :watermark, force: true)
  end

  @doc """
  Removes the watermark.
  """
  def delete_gallery_watermark(watermark) do
    Repo.delete(watermark)
  end

  @doc """
  Clears watermarks of photos and triggers watermarked versions removal
  """
  def clear_watermarks(gallery_id) do
    get_gallery!(gallery_id)
    |> Repo.preload(:photos)
    |> Map.get(:photos)
    |> Enum.each(fn photo ->
      [photo.watermarked_preview_url, photo.watermarked_url]
      |> Enum.each(fn path ->
        %{path: path}
        |> CleanStore.new()
        |> Oban.insert()
      end)

      update_photo(photo, %{watermarked_url: nil, watermarked_preview_url: nil})
    end)
  end

  def gallery_password_change(attrs \\ %{}) do
    Gallery.password_changeset(%Gallery{}, attrs)
  end

  @doc """
  Returns the changeset of watermark struct.
  """
  def gallery_watermark_change(nil), do: Ecto.Changeset.change(%Watermark{})
  def gallery_watermark_change(%Watermark{} = watermark), do: Ecto.Changeset.change(watermark)

  @doc """
  Returns the changeset of watermark struct with :type => "image".
  """
  def gallery_image_watermark_change(%Watermark{} = watermark, attrs),
    do: Watermark.image_changeset(watermark, attrs)

  def gallery_image_watermark_change(nil, attrs),
    do: Watermark.image_changeset(%Watermark{}, attrs)

  @doc """
  Returns the changeset of watermark struct with :type => "text".
  """
  def gallery_text_watermark_change(%Watermark{} = watermark, attrs),
    do: Watermark.text_changeset(watermark, attrs)

  def gallery_text_watermark_change(nil, attrs),
    do: Watermark.text_changeset(%Watermark{}, attrs)

  def save_gallery_cover_photo(gallery, attrs \\ %{}) do
    gallery
    |> Gallery.save_cover_photo_changeset(attrs)
    |> Repo.update!()
  end

  def delete_gallery_cover_photo(gallery) do
    gallery
    |> Gallery.delete_cover_photo_changeset()
    |> Repo.update!()
  end

  @doc """
  Creates session token for the gallery client.
  """
  def build_gallery_session_token(%Gallery{id: id}) do
    %{gallery_id: id}
    |> SessionToken.changeset()
    |> Repo.insert()
  end

  @doc """
  Check if the client session token is suitable for the gallery.
  """
  def session_exists_with_token?(_gallery_id, nil), do: false

  def session_exists_with_token?(gallery_id, token) do
    session_validity_in_days = SessionToken.session_validity_in_days()

    from(token in SessionToken,
      where:
        token.gallery_id == ^gallery_id and token.token == ^token and
          token.inserted_at > ago(^session_validity_in_days, "day")
    )
    |> Repo.one()
    |> then(fn
      nil -> false
      _ -> true
    end)
  end

  @doc """
  Loads the gallery creator.
  """
  def get_gallery_creator(%Gallery{id: _} = gallery) do
    gallery
    |> Repo.preload(job: [client: [organization: :user]])
    |> (& &1.job.client.organization.user).()
  end

  @doc """
  Get list of photo ids from gallery.
  """
  def get_photo_ids(opts) do
    favorites_filter = Keyword.get(opts, :favorites_filter, false)
    exclude_album = Keyword.get(opts, :exclude_album, false)

    conditions = dynamic([p], p.gallery_id == ^opts[:gallery_id])

    conditions =
      if favorites_filter do
        dynamic([p], p.client_liked == true and ^conditions)
      else
        conditions
      end

    conditions =
      if exclude_album do
        dynamic([p], is_nil(p.album_id) and ^conditions)
      else
        conditions
      end

    Photo
    |> where(^conditions)
    |> order_by(asc: :position)
    |> select([photo], photo.id)
    |> Repo.all()
  end

  def account_id(%Gallery{} = gallery), do: account_id(gallery.id)

  def account_id(gallery_id) do
    "Gallery account #{gallery_id}"
    |> then(&:crypto.hash(:sha3_256, &1))
    |> Base.encode64()
  end

  def populate_organization(%Gallery{} = gallery) do
    gallery
    |> Repo.preload(job: [client: :organization])
  end

  def populate_organization_user(%Gallery{} = gallery) do
    gallery
    |> Repo.preload(job: [client: [organization: :user]])
  end

  def download_each_price(%{job_id: job_id}) do
    from(package in Picsello.Package,
      join: job in assoc(package, :jobs),
      where: job.id == ^job_id,
      select: struct(package, [:download_each_price])
    )
    |> Repo.one()
    |> Map.get(:download_each_price)
  end

  def products(%{id: gallery_id}),
    do: Picsello.GalleryProducts.get_gallery_products(gallery_id, :with_or_without_previews)

  def expired?(%Gallery{expired_at: nil}), do: false

  def expired?(%Gallery{expired_at: expired_at}),
    do: DateTime.compare(DateTime.utc_now(), expired_at) in [:eq, :gt]

  def gallery_photographer(%Gallery{} = gallery) do
    %{job: %{client: %{organization: %{user: user}}}} = gallery |> populate_organization_user()
    user
  end
end
