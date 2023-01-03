defmodule Picsello.Galleries.Gallery do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Picsello.Galleries.{Photo, Watermark, CoverPhoto, GalleryProduct, Album, SessionToken}
  alias Picsello.{Job, Cart.Order, Repo, GlobalSettings}

  @status_options [
    values: ~w(draft active expired disabled),
    default: "draft"
  ]

  @session_opts [
    foreign_key: :resource_id,
    where: [resource_type: :gallery],
    on_delete: :delete_all
  ]

  @type_opts [values: ~w(proofing finals standard)a, default: :standard]

  schema "galleries" do
    field :name, :string
    field :status, :string, @status_options
    field :password, :string
    field :client_link_hash, :string
    field :expired_at, :utc_datetime
    field :total_count, :integer, default: 0
    field :active, :boolean, default: true
    field :type, Ecto.Enum, @type_opts
    field :disabled, :boolean, default: false
    field :use_global, :boolean, default: true

    belongs_to(:job, Job)
    belongs_to(:parent, __MODULE__)
    has_many(:photos, Photo)
    has_many(:gallery_products, GalleryProduct)
    has_many(:albums, Album)
    has_many(:orders, Order)
    has_many(:session_tokens, SessionToken, @session_opts)
    has_one(:watermark, Watermark, on_replace: :update)
    has_one(:child, __MODULE__, foreign_key: :parent_id)
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
    :use_global,
    :type,
    :parent_id
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
    gallery
    |> cast(attrs, @create_attrs)
    |> cast_assoc(:albums, with: &Album.changeset_with_gallery/2)
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

  def global_gallery_watermark(gallery) do
    from(j in Picsello.Job,
      join: c in assoc(j, :client),
      join: o in assoc(c, :organization),
      where: j.id == ^gallery.job_id,
      select: o.id
    )
    |> Repo.one()
    |> then(&GlobalSettings.get(&1))
    |> case do
      %{watermark_type: "image", watermark_name: watermark_name, watermark_size: watermark_size} ->
        %{
          gallery_id: gallery.id,
          name: watermark_name,
          size: watermark_size,
          type: "image"
        }

      %{watermark_type: "text", watermark_text: watermark_text} ->
        %{text: watermark_text, type: "text", gallery_id: gallery.id}

      _ ->
        nil
    end
  end
end
