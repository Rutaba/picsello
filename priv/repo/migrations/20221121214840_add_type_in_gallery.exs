defmodule Picsello.Repo.Migrations.AddTypeInGallery do
  use Ecto.Migration
  alias Picsello.Repo

  alias Ecto.Multi
  import Ecto.Query

  def change do
    execute("CREATE TYPE gallery_types AS ENUM ('standard','proofing','finals')")

    alter table(:galleries) do
      add(:type, :gallery_types, null: false, default: "standard")
      add(:parent_id, references(:galleries, on_delete: :nothing))
    end

    flush()

    now = DateTime.utc_now() |> DateTime.truncate(:second)
    albums = Album.list()

    albums
    |> Enum.with_index(1)
    |> Enum.reduce(Multi.new(), fn {album, i}, multi ->
      %{
        gallery: %{gallery_products: gallery_products, job: job, name: name} = gallery,
        photos: photos,
        id: id
      } = album

      key = Gallery.key(album)

      multi
      |> Multi.insert(
        key,
        gallery
        |> Map.take([:status, :active, :disabled, :job_id, :expired_at, :password])
        |> Map.merge(%{
          name: Job.name(job, i),
          type: Gallery.type(album),
          client_link_hash: UUID.uuid4(),
          total_count: Enum.count(photos)
        })
        |> Gallery.changeset()
      )
      |> Multi.update(~s(update-parent-#{id}), Gallery.changeset(gallery, %{name: "#{name} 1"}))
      |> Multi.insert_all(
        ~s(gallery-products-#{id}),
        GalleryProduct,
        fn %{^key => %{id: gallery_id}} ->
          Enum.map(gallery_products, fn product ->
            Map.take(
              product,
              [
                :category_id,
                :product_preview_enabled,
                :sell_product_enabled
              ]
            )
            |> Map.put(:gallery_id, gallery_id)
            |> Map.put(:updated_at, now)
            |> Map.put(:inserted_at, now)
          end)
        end
      )
      |> Multi.update(~s(update-album-#{id}), fn %{^key => %{id: gallery_id}} ->
        Album
        |> Picsello.Repo.get!(id)
        |> Ecto.Changeset.cast(%{gallery_id: gallery_id}, [:gallery_id])
      end)
      |> Multi.update_all(
        ~s(update-photos-#{id}),
        fn %{^key => %{id: gallery_id}} ->
          from(photo in Photo,
            where: photo.album_id == ^id,
            update: [set: [gallery_id: ^gallery_id, updated_at: ^now]]
          )
        end,
        []
      )
      |> Multi.update_all(
        ~s(update-orders-#{id}),
        fn %{^key => %{id: gallery_id}} ->
          from(order in Order,
            where: order.album_id == ^id,
            update: [set: [gallery_id: ^gallery_id, updated_at: ^now]]
          )
        end,
        []
      )
    end)
    |> then(fn ecto_multi ->
      albums
      |> Enum.group_by(& &1.gallery_id)
      |> Enum.reduce(ecto_multi, fn {_gallery_id, albums}, multi ->
        {proofings, finals} = Enum.split_with(albums, & &1.is_proofing)

        Enum.zip_reduce(proofings, finals, multi, fn p, f, multi_acc ->
          p_key = Gallery.key(p)
          f_key = Gallery.key(f)

          multi_acc
          |> Multi.update(~s(final-#{f.id}), fn %{^p_key => %{id: id}, ^f_key => f_gallery} ->
            Gallery.changeset(f_gallery, %{parent_id: id})
          end)
        end)
      end)
    end)
    |> Repo.transaction()
  end
end

defmodule Client do
  use Ecto.Schema

  schema "clients" do
    field :name, :string
  end
end

defmodule Job do
  use Ecto.Schema

  schema "jobs" do
    field :type, :string
    field :job_name, :string
    belongs_to(:client, Client)
  end

  def name(%__MODULE__{type: type, client: %{name: client_name}} = job, i) do
    if job.job_name do
      [job.job_name, i]
    else
      [client_name, Phoenix.Naming.humanize(type), i]
    end
    |> Enum.join(" ")
  end
end

defmodule Gallery do
  use Ecto.Schema

  schema "galleries" do
    field :name, :string
    field(:status, :string)
    field :expired_at, :utc_datetime
    field :total_count, :integer
    field :active, :boolean
    field :type, Ecto.Enum, values: [:proofing, :finals, :standard]
    field :disabled, :boolean
    field :password, :string
    field :client_link_hash, :string

    belongs_to(:job, Job)
    belongs_to(:parent, Gallery)
    has_many :gallery_products, GalleryProduct

    timestamps(type: :utc_datetime)
  end

  def changeset(gallery \\ %__MODULE__{}, attrs) do
    gallery
    |> Ecto.Changeset.cast(attrs, [
      :name,
      :status,
      :expired_at,
      :total_count,
      :active,
      :type,
      :disabled,
      :job_id,
      :parent_id,
      :password,
      :client_link_hash
    ])
  end

  def type(%{is_finals: true}), do: "finals"
  def type(%{is_proofing: true}), do: "proofing"

  def key(album), do: ~s(gallery-insert-#{album.id})
end

defmodule Album do
  use Ecto.Schema

  alias Picsello.Repo
  import Ecto.Query

  schema "albums" do
    field :is_finals, :boolean
    field :is_proofing, :boolean
    belongs_to(:gallery, Gallery)
    has_many :photos, Photo

    timestamps(type: :utc_datetime)
  end

  def list() do
    from(album in Album,
      where: album.is_proofing or album.is_finals,
      preload: [:photos, gallery: [:gallery_products, job: [:client]]]
    )
    |> Repo.all()
  end
end

defmodule Photo do
  use Ecto.Schema

  schema "photos" do
    belongs_to(:album, Album)
    belongs_to(:gallery, Gallery)

    timestamps(type: :utc_datetime)
  end
end

defmodule Order do
  use Ecto.Schema

  schema "gallery_orders" do
    belongs_to(:gallery, Gallery)
    belongs_to(:album, Album)

    timestamps(type: :utc_datetime)
  end
end

defmodule GalleryProduct do
  use Ecto.Schema

  schema "gallery_products" do
    field :sell_product_enabled, :boolean
    field :product_preview_enabled, :boolean
    belongs_to(:category, Category)
    belongs_to(:gallery, Gallery)

    timestamps(type: :utc_datetime)
  end
end

defmodule Category do
  use Ecto.Schema

  schema "categories" do
  end
end
