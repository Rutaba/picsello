defmodule Picsello.Galleries.Gallery do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Picsello.Galleries.{Photo, Watermark, CoverPhoto, GalleryProduct, Album, SessionToken}
  alias Picsello.{Job, Cart.Order, Repo}
  alias Picsello.GlobalSettings.Gallery, as: GSGallery

  @status_options [
    values: ~w(draft active expired disabled),
    default: "draft"
  ]

  @session_opts [
    foreign_key: :resource_id,
    where: [resource_type: :gallery],
    on_delete: :delete_all
  ]

  schema "galleries" do
    field :name, :string
    field(:status, :string, @status_options)
    field :password, :string
    field :client_link_hash, :string
    field :expired_at, :utc_datetime
    field :total_count, :integer, default: 0
    field :active, :boolean, default: true
    field :disabled, :boolean, default: false
    field :use_global, :boolean

    belongs_to(:job, Job)
    has_many(:photos, Photo)
    has_many(:gallery_products, GalleryProduct)
    has_many(:albums, Album)
    has_many(:orders, Order)
    has_many(:session_tokens, SessionToken, @session_opts)
    has_one(:watermark, Watermark, on_replace: :update)
    embeds_one(:cover_photo, CoverPhoto, on_replace: :update)
    has_one(:organization, through: [:job, :client, :organization])
    has_one(:package, through: [:job, :package])
    has_one(:photographer, through: [:job, :client, :organization, :user])

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          organization: Picsello.Organization.t(),
          name: String.t()
        }

  @create_attrs [
    :name,
    :job_id,
    :status,
    :expired_at,
    :client_link_hash,
    :total_count,
    :active,
    :use_global
  ]
  @update_attrs [
    :name,
    :status,
    :expired_at,
    :password,
    :client_link_hash,
    :total_count,
    :active,
    :disabled
  ]
  @required_attrs [:name, :job_id, :status, :password]

  def create_changeset(gallery, attrs \\ %{}) do
    attrs = Map.put(attrs, :expired_at, global_expiration_datetime(attrs))
    attrs = Map.put(attrs, :use_global, true)

    gallery
    |> cast(attrs, @create_attrs)
    |> cast_password()
    |> validate_required(@required_attrs)
    |> validate_status(@status_options[:values])
    |> validate_name()
    |> foreign_key_constraint(:job_id)
  end

  def update_changeset(gallery, attrs \\ %{}) do
    gallery
    |> cast(attrs, @update_attrs)
    |> validate_required(@required_attrs)
    |> validate_status(@status_options[:values])
    |> validate_name()
  end

  def save_watermark(gallery, watermark_changeset) do
    gallery
    |> change
    |> put_assoc(:watermark, watermark_changeset)
  end

  def expire_changeset(gallery, attrs \\ %{}) do
    gallery
    |> cast(attrs, [:expired_at])
  end

  def client_link_changeset(gallery, attrs \\ %{}) do
    gallery
    |> cast(attrs, [:client_link_hash])
    |> validate_required([:client_link_hash])
  end

  def password_changeset(gallery, attrs \\ %{}) do
    gallery
    |> cast(attrs, [:password])
    |> validate_required([:password])
  end

  def save_cover_photo_changeset(gallery, attrs \\ %{}) do
    gallery
    |> cast(attrs, [])
    |> cast_embed(:cover_photo, with: {CoverPhoto, :changeset, [gallery.id]}, required: true)
  end

  def delete_cover_photo_changeset(gallery) do
    gallery
    |> change()
    |> put_embed(:cover_photo, nil)
  end

  def generate_password, do: Enum.random(100_000..999_999) |> to_string

  defp cast_password(changeset),
    do: put_change(changeset, :password, generate_password())

  defp validate_status(changeset, status_formats),
    do: validate_inclusion(changeset, :status, status_formats)

  defp validate_name(changeset),
    do: validate_length(changeset, :name, max: 50)

  defp global_expiration_datetime(gallery) do
    case gallery do
      %{} ->
        nil

      _ ->
        organization_id =
          from(j in Picsello.Job,
            join: c in assoc(j, :client),
            join: o in assoc(c, :organization),
            where: j.id == ^gallery.job_id,
            select: o.id
          )
          |> Repo.one()

        shoot = get_shoots(gallery.job_id) |> List.last()

        settings =
          from(gss in GSGallery,
            where: gss.organization_id == ^organization_id
          )
          |> Repo.one()

        if settings && settings.expiration_days && settings.expiration_days > 0 do
          Timex.shift(shoot.starts_at, days: settings.expiration_days) |> Timex.to_datetime()
        end
    end
  end

  def global_gallery_watermark(gallery) do
    organization_id =
      from(j in Picsello.Job,
        join: c in assoc(j, :client),
        join: o in assoc(c, :organization),
        where: j.id == ^gallery.job_id,
        select: o.id
      )
      |> Repo.one()

    settings =
      from(gss in GSGallery,
        where: gss.organization_id == ^organization_id
      )
      |> Repo.one()

    if settings do
      case settings.watermark_type do
        "image" ->
          %{
            gallery_id: gallery.id,
            name: settings.watermark_name,
            size: settings.watermark_size,
            type: "image"
          }

        "text" ->
          %{text: settings.watermark_text, type: "text", gallery_id: gallery.id}

        _ ->
          nil
      end
    end
  end

  defp get_shoots(job_id), do: Picsello.Shoot.for_job(job_id) |> Repo.all()
end
