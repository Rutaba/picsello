defmodule Picsello.Galleries do
  @moduledoc """
  The Galleries context.
  """

  import Ecto.Query, warn: false
  import PicselloWeb.GalleryLive.Shared, only: [prepare_gallery: 1]

  alias Ecto.Multi

  alias Picsello.{
    Galleries,
    Repo,
    Photos,
    Category,
    GalleryProducts,
    Galleries,
    Albums,
    Orders,
    Cart.Digital,
    Job,
    Client,
    WHCC,
    Galleries.Gallery.UseGlobal
  }

  alias Picsello.GlobalSettings.Gallery, as: GSGallery
  alias Picsello.Workers.CleanStore
  alias Galleries.PhotoProcessing.ProcessingManager
  alias Galleries.{Gallery, Photo, Watermark, SessionToken, GalleryProduct, Album}
  import Repo.CustomMacros

  @area_markup_category Picsello.Category.print_category()

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
    from(g in active_galleries(), where: g.status == :expired)
    |> Repo.all()
  end

  @setting_types :fields |> UseGlobal.__schema__() |> Enum.map(&to_string/1)
  def list_shared_setting_galleries(organization_id, type) when type in @setting_types do
    organization_id
    |> list_all_galleries_by_organization_query()
    |> where([g], fragment("? ->> ? = 'true'", g.use_global, ^type))
    |> Repo.all()
  end

  def list_all_galleries_by_organization_query(organization_id) do
    from(g in active_disabled_galleries(),
      join: j in Job,
      on: j.id == g.job_id,
      join: c in Client,
      on: c.id == j.client_id,
      preload: [:albums, [job: :client]],
      where: c.organization_id == ^organization_id
    )
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
  def get_gallery!(id) do
    from(gallery in active_disabled_galleries(),
      where: gallery.id == ^id
    )
    |> Repo.one!()
  end

  @doc """
  List galleries against job_id

  ## Examples

      iex> get_galleries_by_job_id(job_id)
      [%Gallery{}, ...]

      iex> get_galleries_by_job_id(job_id)
      []

  """
  def get_galleries_by_job_id(job_id),
    do: where(active_galleries(), job_id: ^job_id) |> order_by([:inserted_at]) |> Repo.all()

  @doc """
  Gets a single gallery by hash parameter.

  Returns nil if the Gallery does not exist.

  ## Examples

      iex> get_gallery_by_hash("validhash")
      %Gallery{}

      iex> get_gallery_by_hash("wronghash")
      nil

  """
  @spec get_gallery_by_hash(hash :: binary) :: Gallery.t() | nil
  def get_gallery_by_hash(hash), do: Repo.get_by(active_galleries(), client_link_hash: hash)

  @spec get_gallery_by_hash!(hash :: binary) :: Gallery.t()
  def get_gallery_by_hash!(hash),
    do: Repo.get_by!(active_disabled_galleries(), client_link_hash: hash)

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
    * :photographer_favorites_filter
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
    exclude_album = Keyword.get(opts, :exclude_album, false)
    album_id = Keyword.get(opts, :album_id, false)

    opts
    |> Enum.reduce(dynamic([p], p.gallery_id == ^id), fn
      {:favorites_filter, true}, conditions ->
        dynamic([p], p.client_liked == true and ^conditions)

      {:photographer_favorites_filter, true}, conditions ->
        dynamic([p], p.is_photographer_liked == true and ^conditions)

      {:valid, true}, conditions ->
        dynamic([p], not is_nil(p.height) and not is_nil(p.width) and ^conditions)

      {:exclude_album, true}, conditions ->
        dynamic([p], is_nil(p.album_id) and ^conditions)

      _, conditions ->
        conditions
    end)
    |> then(fn
      conditions when exclude_album != true and is_integer(album_id) ->
        dynamic([p], p.album_id == ^album_id and ^conditions)

      conditons ->
        conditons
    end)
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

  @types ~w(proofing finals)a
  defp move_photos_from_album_transaction(photo_ids, gallery \\ nil) do
    Multi.new()
    |> Multi.update_all(
      :thumbnail,
      fn _ -> Albums.remove_album_thumbnail(photo_ids) end,
      []
    )
    |> Multi.update_all(
      :photos,
      fn _ ->
        from(p in Photo,
          where: p.id in ^photo_ids,
          update: [set: ^photo_opts(gallery)]
        )
      end,
      []
    )
    |> then(fn
      multi when not is_nil(gallery) and gallery.type in @types ->
        multi
        |> Multi.run(:gallery, fn _, %{photos: {count, _}} ->
          update_gallery(gallery, %{total_count: gallery.total_count - count})
        end)

      multi ->
        multi
    end)
  end

  defp photo_opts(%{type: type}) when type in @types, do: [active: false]
  defp photo_opts(_gallery), do: [album_id: nil]

  def remove_photos_from_album(photo_ids, gallery_id) do
    gallery = get_gallery!(gallery_id)

    photo_ids
    |> move_photos_from_album_transaction(gallery)
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
    |> Multi.delete(:album, album)
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

    Multi.new()
    |> Multi.update_all(
      :preview,
      fn _ -> GalleryProducts.remove_photo_preview(photo_ids) end,
      []
    )
    |> Multi.update(
      :cover_photo,
      fn _ -> delete_gallery_cover_photo(photo.gallery_id, photos) end,
      []
    )
    |> Multi.update_all(
      :thumbnail,
      fn _ -> Albums.remove_album_thumbnail(photo_ids) end,
      []
    )
    |> Multi.update_all(
      :photos,
      fn _ -> from(p in Photo, where: p.id in ^photo_ids, update: [set: [active: false]]) end,
      []
    )
    |> Repo.transaction()
    |> then(fn
      {:ok, %{photos: photos}} ->
        gallery = get_gallery!(photo.gallery_id)
        prepare_gallery(gallery)
        refresh_bundle(gallery)
        {:ok, photos}

      {:error, reason} ->
        reason
    end)
  end

  @doc """
  delete the photos if they are duplicated
  """
  def delete_photos_by(photo_ids) do
    from(p in Photo,
      where: p.id in ^photo_ids
    )
    |> Repo.update_all(set: [active: false])
  end

  def get_photo_by_id(photo_id) do
    from(p in Photos.active_photos(), where: p.id == ^photo_id)
    |> Repo.one()
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

  def pack(gallery, photo_ids, opts \\ []) when is_list(photo_ids) do
    %{
      photo_ids: photo_ids,
      gallery_name: gallery.name,
      gallery_url: PicselloWeb.Helpers.gallery_url(gallery),
      email: opts[:user_email]
    }
    |> Picsello.Workers.PackPhotos.new()
    |> Oban.insert()
  end

  @spec get_gallery_photos_count(gallery_id :: integer) :: integer
  def get_gallery_photos_count(gallery_id) do
    from(g in active_galleries(),
      join: p in Photo,
      on: p.gallery_id == g.id,
      where: p.active == true and g.id == ^gallery_id,
      select: count(p.id)
    )
    |> Repo.one()
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
    attrs
    |> create_gallery_multi()
    |> Repo.transaction()
    |> case do
      {:ok, %{gallery: gallery}} -> {:ok, gallery}
      {:error, :gallery, changeset, _} -> {:error, changeset}
      other -> other
    end
  end

  def create_gallery_multi(attrs) do
    Multi.new()
    |> Multi.insert(:gallery, Gallery.create_changeset(%Gallery{}, attrs))
    |> Multi.insert_all(
      :gallery_products,
      GalleryProduct,
      fn %{
           gallery: %{
             id: gallery_id,
             type: type
           }
         } ->
        case type do
          :proofing ->
            []

          _ ->
            from(category in (Category.active() |> Category.shown()),
              select: %{
                inserted_at: now(),
                updated_at: now(),
                gallery_id: ^gallery_id,
                category_id: category.id
              }
            )
        end
      end
    )
    |> Multi.merge(fn %{gallery: gallery} ->
      gallery
      |> Repo.preload(job: [:client, :package])
      |> check_digital_pricing()
    end)
    |> Multi.merge(fn %{gallery: gallery} ->
      gallery
      |> Repo.preload(:package)
      |> check_watermark()
    end)
  end

  defp check_watermark(%{package: %{download_each_price: %Money{amount: 0}}}), do: Multi.new()

  defp check_watermark(gallery) do
    case Gallery.global_gallery_watermark(gallery) do
      nil ->
        Multi.new()

      watermark ->
        Multi.new()
        |> Multi.insert(:watermark, fn _ ->
          Ecto.Changeset.change(
            %Watermark{},
            watermark
          )
        end)
    end
  end

  defp check_digital_pricing(%{job: %{package: package, client: client}} = gallery) do
    first_gallery = get_first_gallery(gallery)

    case package do
      nil ->
        Multi.new()

      package ->
        Multi.new()
        |> Multi.update(
          :gallery_digital_pricing,
          Gallery.save_digital_pricing_changeset(gallery, %{
            gallery_digital_pricing: %{
              buy_all: package.buy_all,
              print_credits:
                if(first_gallery.id == gallery.id,
                  do: package.print_credits,
                  else: Money.new(0)
                ),
              download_count: package.download_count,
              download_each_price: package.download_each_price,
              email_list: [client.email]
            }
          }),
          []
        )
    end
  end

  def reset_gallery_pricing(gallery) do
    first_gallery = get_first_gallery(gallery)

    Gallery.save_digital_pricing_changeset(gallery, %{
      gallery_digital_pricing: %{
        buy_all: gallery.package.buy_all,
        print_credits:
          if(first_gallery.id == gallery.id,
            do: gallery.package.print_credits,
            else: Money.new(0)
          ),
        download_count: gallery.package.download_count,
        download_each_price: gallery.package.download_each_price
      }
    })
    |> Repo.update()
  end

  def get_first_gallery(%Gallery{job_id: job_id}) do
    from(g in Gallery,
      where: g.job_id == ^job_id and g.status == :active,
      order_by: g.inserted_at,
      limit: 1
    )
    |> Repo.one()
  end

  def album_params_for_new("standard"), do: []

  def album_params_for_new(type),
    do: [
      %{
        name: type,
        is_proofing: type == "proofing",
        is_finals: type == "finals",
        set_password: false
      }
    ]

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

  alias Ecto.Changeset

  def save_use_global(multi, %Gallery{use_global: global} = gallery, use_global) do
    {:ok, _} =
      use_global
      |> Map.keys()
      |> Enum.any?(&Map.get(global, &1))
      |> case do
        true ->
          Multi.update(
            multi,
            :update_use_global,
            Changeset.change(gallery, %{use_global: use_global})
          )

        false ->
          multi
      end
      |> Repo.transaction()
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

    Multi.new()
    |> Multi.update(:gallery, changeset)
    |> Multi.delete_all(:session_tokens, gallery_session_tokens_query(gallery))
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
    update_gallery(gallery, %{status: :inactive})
  end

  def delete_gallery_by_id(id), do: get_gallery!(id) |> delete_gallery()

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
  def update_photo(photo_id, %{} = attrs) when is_integer(photo_id) do
    case Repo.get(Photo, photo_id) |> Repo.preload(:gallery) do
      nil ->
        {:error, :no_photo}

      %{gallery: %{total_count: 1} = gallery} = photo ->
        Multi.new()
        |> Multi.update(:photo, Photo.update_changeset(photo, attrs))
        |> Multi.run(:gallery, fn _, _ -> may_be_prepare_gallery(gallery, photo) end)
        |> Repo.transaction()
        |> case do
          {:ok, %{photo: photo}} -> {:ok, photo}
          err -> err
        end

      photo ->
        photo
        |> Photo.update_changeset(attrs)
        |> Repo.update()
    end
  end

  def update_photo(_, %{} = _attrs), do: {:error, :no_photo}

  def may_be_prepare_gallery(gallery, photo) do
    gallery
    |> products()
    |> Enum.filter(fn
      %{preview_photo: %{id: id}} when not is_nil(id) -> false
      _ -> true
    end)
    |> Enum.reduce(Multi.new(), fn %{category_id: category_id} = product, multi ->
      multi
      |> Multi.run(product.id, fn _, _ ->
        product
        |> Map.drop([:category, :preview_photo])
        |> GalleryProducts.upsert_gallery_product(%{
          preview_photo_id: photo.id,
          category_id: category_id
        })
      end)
    end)
    |> Multi.run(:cover_photo, fn _, _ -> maybe_set_product_previews(gallery, photo) end)
    |> Repo.transaction()
  end

  def maybe_set_product_previews(%{cover_photo: cover_photo} = gallery, photo) do
    case cover_photo do
      %Photo{} ->
        {:ok, cover_photo}

      _ ->
        save_gallery_cover_photo(
          gallery,
          %{
            cover_photo:
              photo
              |> Map.take([:aspect_ratio, :width, :height])
              |> Map.put(:id, photo.original_url)
          }
        )
    end
  end

  @doc """
  get name of the selected photos
  """
  def get_selected_photos_name(selected_photo_ids) do
    from(p in Photo,
      where: p.id in ^selected_photo_ids,
      select: fragment("REPLACE(?,?,?)", p.name, "_final", "")
    )
    |> Repo.all()
  end

  @doc """
  filter the photos that are duplicated and returns id of filtered photos
  """
  def filter_duplication(selected_photo_ids, album_id) do
    from(p in Photo,
      join: a in assoc(p, :album),
      where: fragment("REPLACE(?,?,?)", p.name, "_final", "") in ^selected_photo_ids,
      where: a.id == ^album_id,
      select: p.id
    )
    |> Repo.all()
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

  def update_all(galleries, total_days) when is_list(galleries) do
    galleries =
      if total_days == 0 do
        galleries
        |> Enum.map(
          &[
            id: &1.id,
            name: &1.name,
            updated_at: &1.updated_at,
            inserted_at: &1.inserted_at,
            status: &1.status,
            job_id: &1.job_id,
            expired_at: nil
          ]
        )
      else
        galleries
        |> Enum.map(
          &[
            id: &1.id,
            name: &1.name,
            updated_at: &1.updated_at,
            inserted_at: &1.inserted_at,
            status: &1.status,
            job_id: &1.job_id,
            expired_at: GSGallery.calculate_expiry_date(total_days, &1.inserted_at)
          ]
        )
      end

    Repo.insert_all(Gallery, galleries,
      on_conflict: {:replace, [:expired_at]},
      conflict_target: :id
    )
  end

  def gallery_current_status(%Gallery{id: nil}), do: :none_created

  def gallery_current_status(%Gallery{status: :expired}), do: :deactivated

  def gallery_current_status(%Gallery{} = gallery) do
    gallery = Repo.preload(gallery, [:photos, :organization])

    gallery
    |> Orders.has_proofing_album_orders?()
    |> if(do: :selections_available, else: uploading_status(gallery))
  end

  def save_galleries_watermark(galleries, watermark_change) do
    galleries
    |> Enum.reduce(Multi.new(), fn %{id: id} = gallery, multi ->
      Multi.run(multi, id, fn _, _ ->
        save_gallery_watermark(gallery, watermark_change)
      end)
    end)
    |> Repo.transaction()
  end

  @doc """
  Creates or updates watermark of the gallery.
  And triggers photo watermarking
  """
  def save_gallery_watermark(gallery, watermark_change) do
    gallery
    |> save_watermark(watermark_change)
    |> tap(fn
      {:ok, gallery} -> apply_watermark_on_photos(gallery)
      x -> x
    end)
  end

  def save_watermark(gallery, watermark_change) do
    gallery
    |> Repo.preload(:watermark)
    |> Gallery.save_watermark(watermark_change)
    |> Repo.update()
  end

  def apply_watermark_on_photos(gallery) do
    gallery = gallery |> Repo.preload([:watermark])

    get_gallery_photos(gallery.id)
    |> Enum.each(&ProcessingManager.update_watermark(&1, gallery.watermark))
  end

  @doc """
  Preloads the watermark of the gallery.
  """
  def load_watermark_in_gallery(%Gallery{} = gallery) do
    Repo.preload(gallery, :watermark, force: true)
  end

  def delete_multiple_watermarks(gallery_ids) do
    clear_watermarks = fn multi, gallery_id ->
      Multi.run(multi, gallery_id, fn _, _ -> clear_watermarks(gallery_id) end)
    end

    Multi.new()
    |> Multi.delete_all(
      :delete_watermarks,
      from(w in Watermark, where: w.gallery_id in ^gallery_ids)
    )
    |> then(fn m -> Enum.reduce(gallery_ids, m, &clear_watermarks.(&2, &1)) end)
    |> Repo.transaction()
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
    %{job: %{client: %{organization: %{name: name}}}} =
      gallery = get_gallery!(gallery_id) |> populate_organization()

    gallery
    |> Repo.preload(photos: [:album])
    |> Map.get(:photos)
    |> Enum.reduce({[], []}, fn
      %{album: %{is_proofing: true}} = photo, acc ->
        ProcessingManager.start(photo, Watermark.build(name, gallery))
        acc

      photo, {photo_ids, oban_jobs} ->
        {
          [photo.id | photo_ids],
          [photo.watermarked_preview_url, photo.watermarked_url]
          |> Enum.map(fn path -> CleanStore.new(%{path: path}) end)
          |> Enum.concat(oban_jobs)
        }
    end)
    |> then(fn
      {[], []} ->
        {:ok, %{}}

      {photo_ids, oban_jobs} ->
        Multi.new()
        |> Multi.update_all(
          :photos,
          fn _ ->
            from(p in Photo,
              where: p.id in ^photo_ids,
              update: [set: [watermarked_url: nil, watermarked_preview_url: nil]]
            )
          end,
          []
        )
        |> Oban.insert_all(:clean_store, oban_jobs)
        |> Repo.transaction()
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
  Returns the changeset of watermark struct with :type => :image.
  """
  def gallery_image_watermark_change(%Watermark{} = watermark, attrs),
    do: Watermark.image_changeset(watermark, attrs)

  def gallery_image_watermark_change(nil, attrs),
    do: Watermark.image_changeset(%Watermark{}, attrs)

  @doc """
  Returns the changeset of watermark struct with :type => :text.
  """
  def gallery_text_watermark_change(%Watermark{} = watermark, attrs),
    do: Watermark.text_changeset(watermark, attrs)

  def gallery_text_watermark_change(nil, attrs),
    do: Watermark.text_changeset(%Watermark{}, attrs)

  def save_gallery_cover_photo(gallery, attrs \\ %{}) do
    gallery
    |> Gallery.save_cover_photo_changeset(attrs)
    |> Repo.update()
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
        Enum.count(photos, &(&1.original_url == original_url))
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

  def products(%{} = gallery),
    do: Picsello.GalleryProducts.get_gallery_products(gallery, :with_or_without_previews)

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

  def do_not_charge_for_download?(%Gallery{} = gallery) do
    gallery = gallery |> Picsello.Repo.preload(:gallery_digital_pricing)
    Map.get(gallery.gallery_digital_pricing, :download_each_price) |> Money.zero?()
  end

  def max_price(%{whcc_id: @area_markup_category} = category, org_id, %{
        use_global: %{products: true}
      }) do
    category.id
    |> print_product_sizes(org_id)
    |> Enum.max_by(&Decimal.to_float(&1.final_cost), fn -> %{} end)
    |> WHCC.final_cost()
  end

  def max_price(category, _, %{use_global: use_global}) do
    category
    |> update_markup(use_global)
    |> Picsello.WHCC.max_price_details()
    |> evaluate_price()
  end

  defp print_product_sizes(category_id, organization_id) do
    from(print_product in Picsello.GlobalSettings.PrintProduct,
      join: gs_gallery_product in assoc(print_product, :global_settings_gallery_product),
      where: gs_gallery_product.organization_id == ^organization_id,
      where: gs_gallery_product.category_id == ^category_id,
      select: print_product.sizes
    )
    |> Repo.all()
    |> Enum.concat()
  end

  def min_price(%{whcc_id: @area_markup_category} = category, org_id, %{
        use_global: %{products: true}
      }) do
    category.id
    |> print_product_sizes(org_id)
    |> Enum.min_by(&Decimal.to_float(&1.final_cost), fn -> %{} end)
    |> WHCC.final_cost()
  end

  def min_price(category, _, %{use_global: use_global}) do
    category
    |> update_markup(use_global)
    |> Picsello.WHCC.min_price_details()
    |> evaluate_price()
  end

  defp update_markup(%{gs_gallery_products: [%{markup: markup}]} = category, %{
         products: products?
       }) do
    if products? do
      %{category | default_markup: markup}
    else
      category
    end
  end

  defp evaluate_price(details) do
    details
    |> Picsello.Cart.Product.new()
    |> Picsello.Cart.Product.example_price()
  end

  def preview_image(gallery) do
    photo_query = Photos.watermarked_query()

    photo =
      from(p in photo_query, where: p.gallery_id == ^gallery.id, order_by: p.position, limit: 1)
      |> Repo.one()

    if photo, do: Photos.preview_url(photo, [])
  end

  defp selected_photo_query(query) do
    join(query, :inner, [photo], digital in Digital, on: photo.id == digital.photo_id)
  end

  defp uploading_status(%{photos: []}), do: :no_photo

  defp uploading_status(gallery) do
    gallery
    |> Map.get(:photos, [])
    |> Enum.any?(fn photo ->
      is_nil(photo.aspect_ratio) ||
        is_nil(photo.preview_url)
    end)
    |> if(do: :upload_in_progress, else: :ready)
  end

  def broadcast(gallery, message),
    do: Phoenix.PubSub.broadcast(Picsello.PubSub, topic(gallery), message)

  def subscribe(gallery), do: Phoenix.PubSub.subscribe(Picsello.PubSub, topic(gallery))

  defp topic(gallery), do: "gallery:#{gallery.id}"

  defp active_galleries, do: from(g in Gallery, where: g.status == :active)

  defp active_disabled_galleries,
    do: from(g in Gallery, where: g.status in [:active, :disabled])

  defdelegate get_photo(id), to: Picsello.Photos, as: :get
  defdelegate refresh_bundle(gallery), to: Picsello.Workers.PackGallery, as: :enqueue
end
