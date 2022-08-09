defmodule Picsello.Galleries do
  @moduledoc """
  The Galleries context.
  """

  import Ecto.Query, warn: false
  import PicselloWeb.GalleryLive.Shared, only: [prepare_gallery: 1]

  alias Picsello.{
    Repo,
    Photos,
    Category,
    GalleryProducts,
    Galleries,
    Albums,
    Orders,
    Cart.Digital
  }

  alias Picsello.Workers.CleanStore
  alias Galleries.PhotoProcessing.ProcessingManager
  alias Galleries.{Gallery, Photo, Watermark, SessionToken, GalleryProduct, Album}
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
    from(g in active_galleries(), where: g.status == "expired")
    |> Repo.all()
  end

  @doc """
  Returns the list of soon to be expired galleries.

  ## Examples

      iex> list_soon_to_be_expired_galleries()
      [%Gallery{}, ...]

  """
  def list_soon_to_be_expired_galleries(date) do
    from(g in active_galleries(), where: g.expired_at <= ^date)
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
  def get_gallery!(id), do: Repo.get_by!(active_galleries(), id: id)

  @doc """
  Gets a single gallery by job id parameter.

  Returns nil if the Gallery does not exist.

  ## Examples

      iex> get_gallery_by_job_id(job_id)
      %Gallery{}

      iex> get_gallery_by_job_id(job_id)
      nil

  """
  @spec get_gallery_by_job_id(job_id :: integer) :: %Gallery{} | nil
  def get_gallery_by_job_id(job_id), do: Repo.get_by(active_galleries(), job_id: job_id)

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
  def get_gallery_by_hash(hash), do: Repo.get_by(active_galleries(), client_link_hash: hash)

  @spec get_gallery_by_hash!(hash :: binary) :: %Gallery{}
  def get_gallery_by_hash!(hash), do: Repo.get_by!(active_galleries(), client_link_hash: hash)

  @doc """
  Gets single gallery by hash, with relations populated (cover_photo)
  """
  def get_detailed_gallery_by_hash(hash) do
    Repo.preload(get_gallery_by_hash(hash), [:cover_photo])
  end

  @type get_gallery_photos_option ::
          {:offset, number()}
          | {:limit, number()}
          | {:album_id, number()}
          | {:exclude_album, boolean()}
          | {:favorites_filter, boolean()}
  @doc """
  Gets paginated photos by gallery id

  Options:
    * :favorites_filter. If set to `true`, then only liked photos will be returned. Defaults to `false`;
    * :exclude_album. if set to `true`, then only unsorted photos(photos not associated with any album) will be returned. Defaluts to `false`;
    * :album_id
    * :offset
    * :limit
  """
  @spec get_gallery_photos(id :: integer, opts :: list(get_gallery_photos_option)) ::
          list(Photo)
  def get_gallery_photos(id, opts \\ []) do
    from(photo in Photos.watermarked_query())
    |> where(^conditions(id, opts))
    |> then(
      &case Keyword.get(opts, :selected_filter) do
        true -> selected_photo_query(&1)
        _ -> &1
      end
    )
    |> order_by(asc: :position)
    |> then(
      &case Keyword.get(opts, :offset) do
        nil -> &1
        number -> offset(&1, ^number)
      end
    )
    |> then(
      &case Keyword.get(opts, :limit) do
        nil -> &1
        number -> limit(&1, ^number)
      end
    )
    |> Repo.all()
  end

  @doc """
  Get list of photo ids from gallery.
  """
  @spec get_gallery_photo_ids(id :: integer, opts :: keyword) :: list(integer)
  def get_gallery_photo_ids(id, opts) do
    Photos.active_photos()
    |> where(^conditions(id, opts))
    |> order_by(asc: :position)
    |> select([photo], photo.id)
    |> Repo.all()
  end

  defp conditions(id, opts) do
    favorites_filter = Keyword.get(opts, :favorites_filter, false)
    exclude_album = Keyword.get(opts, :exclude_album, false)
    album_id = Keyword.get(opts, :album_id, false)

    conditions = dynamic([p], p.gallery_id == ^id)

    conditions =
      if favorites_filter do
        dynamic([p], p.client_liked == true and ^conditions)
      else
        conditions
      end

    if exclude_album do
      dynamic([p], is_nil(p.album_id) and ^conditions)
    else
      if album_id do
        dynamic([p], p.album_id == ^album_id and ^conditions)
      else
        conditions
      end
    end
  end

  @spec get_all_album_photos(
          id :: integer,
          album_id :: integer
        ) ::
          list(Photo)
  def get_all_album_photos(id, album_id) do
    Photos.active_photos()
    |> where([p], p.gallery_id == ^id and p.album_id == ^album_id)
    |> order_by(asc: :position)
    |> Repo.all()
  end

  @spec get_all_unsorted_photos(id :: integer) :: list(Photo)
  def get_all_unsorted_photos(id) do
    Photos.active_photos()
    |> where([p], p.gallery_id == ^id and is_nil(p.album_id))
    |> order_by(asc: :position)
    |> Repo.all()
  end

  defp move_photos_from_album_transaction(photo_ids) do
    Ecto.Multi.new()
    |> Ecto.Multi.update_all(
      :thumbnail,
      fn _ -> Albums.remove_album_thumbnail(photo_ids) end,
      []
    )
    |> Ecto.Multi.update_all(
      :photos,
      fn _ ->
        from(p in Photo,
          where: p.id in ^photo_ids,
          update: [set: [album_id: nil]]
        )
      end,
      []
    )
  end

  def remove_photos_from_album(photo_ids) do
    move_photos_from_album_transaction(photo_ids)
    |> Repo.transaction()
    |> then(fn
      {:ok, _} ->
        {:ok, photo_ids}

      {:error, reason} ->
        reason
    end)
  end

  def delete_album(album) do
    album = album |> Repo.preload(:photos)
    photo_ids = Enum.map(album.photos, & &1.id)

    move_photos_from_album_transaction(photo_ids)
    |> Ecto.Multi.delete(:album, album)
    |> Repo.transaction()
    |> then(fn
      {:ok, _} ->
        {:ok, album}

      {:error, reason} ->
        reason
    end)
  end

  @doc """
  Deletes photos by photo_ids.

  ## Examples

      iex> delete_photos(photo_ids)
      {non_neg_integer(), nil | [%photo{}]}
  """
  def delete_photos(photo_ids) do
    photos = get_photos_by_ids(photo_ids)
    [photo | _] = photos

    Ecto.Multi.new()
    |> Ecto.Multi.update_all(
      :preview,
      fn _ -> GalleryProducts.remove_photo_preview(photo_ids) end,
      []
    )
    |> Ecto.Multi.update(
      :cover_photo,
      fn _ -> delete_gallery_cover_photo(photo.gallery_id, photos) end,
      []
    )
    |> Ecto.Multi.update_all(
      :thumbnail,
      fn _ -> Albums.remove_album_thumbnail(photo_ids) end,
      []
    )
    |> Ecto.Multi.update_all(
      :photos,
      fn _ -> from(p in Photo, where: p.id in ^photo_ids, update: [set: [active: false]]) end,
      []
    )
    |> Repo.transaction()
    |> then(fn
      {:ok, %{photos: photos}} ->
        prepare_gallery(get_gallery!(photo.gallery_id))
        {:ok, photos}

      {:error, reason} ->
        reason
    end)
  end

  @spec get_photos_by_ids(photo_ids :: list(any)) :: list(Photo)
  def get_photos_by_ids(photo_ids) do
    from(p in Photos.active_photos(), where: p.id in ^photo_ids)
    |> Repo.all()
  end

  def get_photos_by_ids(gallery, photo_ids) do
    from(p in Photos.active_photos(), where: p.id in ^photo_ids and p.gallery_id == ^gallery.id)
    |> Repo.all()
  end

  @spec get_albums_photo_count(gallery_id :: integer) :: integer
  def get_albums_photo_count(gallery_id) do
    from(p in Photos.active_photos(),
      select: count(p.id),
      where: p.gallery_id == ^gallery_id and not is_nil(p.album_id)
    )
    |> Repo.one()
  end

  @spec get_album_photo_count(
          gallery_id :: integer,
          album_id :: integer,
          favorites_filter :: boolean
        ) :: integer
  def get_album_photo_count(gallery_id, album_id, client_liked \\ false, selected \\ false) do
    conditions = dynamic([p], p.gallery_id == ^gallery_id and p.album_id == ^album_id)

    Photos.active_photos()
    |> where(
      ^if(client_liked,
        do: dynamic([p], p.client_liked == ^client_liked and ^conditions),
        else: conditions
      )
    )
    |> then(&if selected, do: selected_photo_query(&1), else: &1)
    |> select([p], count(p.id))
    |> Repo.one()
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
    from(st in SessionToken, where: st.resource_id == ^gallery.id and st.resource_type == :gallery)
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
    update_gallery(gallery, %{active: false})
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
  def move_to_album(album_id, selected_photos) do
    from(p in Photo,
      where: p.id in ^selected_photos
    )
    |> Repo.update_all(set: [album_id: album_id])
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
    gallery = Repo.preload(gallery, [:photos, :organization])

    gallery.organization.id
    |> Orders.get_all_proofing_album_orders()
    |> Enum.any?(fn %{gallery: %{id: id}} ->
      id == gallery.id
    end)
    |> then(fn
      true -> :selections_available
      false -> uploading_status(gallery)
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

  def delete_gallery_cover_photo(gallery_id, photos) do
    gallery = get_gallery!(gallery_id)

    case gallery do
      %{cover_photo: %{id: nil}} ->
        Gallery.update_changeset(gallery)

      %{cover_photo: %{id: original_url}} ->
        Enum.filter(photos, &(&1.original_url == original_url))
        |> Enum.count()
        |> case do
          0 -> Gallery.update_changeset(gallery)
          _ -> Gallery.delete_cover_photo_changeset(gallery)
        end

      _ ->
        Gallery.update_changeset(gallery)
    end
  end

  @doc """
  Creates session token for the gallery client.
  """
  def build_gallery_session_token(%Gallery{id: id, password: gallery_password}, password) do
    with true <- gallery_password == password,
         {:ok, %{token: token}} <-
           insert_session_token(%{resource_id: id, resource_type: :gallery}) do
      {:ok, token}
    else
      _ -> {:error, "cannot log in with that password"}
    end
  end

  def build_gallery_session_token("" <> hash, password) do
    hash |> get_gallery_by_hash!() |> build_gallery_session_token(password)
  end

  def build_album_session_token(%Album{id: id, password: album_password}, password) do
    with true <- album_password == password,
         {:ok, %{token: token}} <- insert_session_token(%{resource_id: id, resource_type: :album}) do
      {:ok, token}
    else
      _ -> {:error, "cannot log in with that password"}
    end
  end

  def insert_session_token(attrs) do
    attrs
    |> SessionToken.changeset()
    |> Repo.insert()
  end

  @doc """
  Check if the client session token is suitable for the resource.
  """
  def session_exists_with_token?(_resource_id, nil, _resource_type), do: false

  def session_exists_with_token?(resource_id, token, resource_type) do
    session_validity_in_days = SessionToken.session_validity_in_days()

    from(token in SessionToken,
      where:
        token.resource_id == ^resource_id and token.token == ^token and
          token.inserted_at > ago(^session_validity_in_days, "day") and
          token.resource_type == ^resource_type
    )
    |> Repo.exists?()
  end

  @doc """
  Loads the gallery creator.
  """
  def get_gallery_creator(%Gallery{id: _} = gallery) do
    gallery
    |> Repo.preload(job: [client: [organization: :user]])
    |> (& &1.job.client.organization.user).()
  end

  def account_id(%Gallery{} = gallery), do: account_id(gallery.id)

  def account_id(gallery_id) do
    "Gallery account #{gallery_id}"
    |> then(&:crypto.hash(:sha3_256, &1))
    |> Base.encode64()
  end

  def populate_organization(%Gallery{} = gallery) do
    gallery
    |> Repo.preload([:package, job: [client: :organization]])
  end

  def populate_organization_user(%Gallery{} = gallery) do
    gallery
    |> Repo.preload([:package, job: [client: [organization: :user]]])
  end

  def download_each_price(%Gallery{} = gallery) do
    gallery |> get_package() |> Map.get(:download_each_price)
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

  def get_package(%Gallery{} = gallery) do
    gallery |> Repo.preload(:package) |> Map.get(:package)
  end

  def do_not_charge_for_download?(%Gallery{} = gallery),
    do: gallery |> get_package() |> Map.get(:download_each_price) |> Money.zero?()

  def min_price(category) do
    category
    |> Picsello.WHCC.min_price_details()
    |> Picsello.Cart.Product.new()
    |> Picsello.Cart.Product.example_price()
  end

  defp selected_photo_query(query) do
    join(query, :inner, [photo], digital in Digital, on: photo.id == digital.photo_id)
  end

  defp uploading_status(gallery) do
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

  defp active_galleries, do: from(g in Gallery, where: g.active == true)

  defdelegate get_photo(id), to: Picsello.Photos, as: :get
end
