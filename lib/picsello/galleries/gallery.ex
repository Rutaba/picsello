defmodule Picsello.Galleries.Gallery do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Galleries.{Photo, Watermark, CoverPhoto, GalleryProduct, Album}
  alias Picsello.Job

  @status_options [
    values: ~w(draft active expired),
    default: "draft"
  ]

  schema "galleries" do
    field :name, :string
    field(:status, :string, @status_options)
    field :password, :string
    field :client_link_hash, :string
    field :expired_at, :utc_datetime
    field :total_count, :integer

    belongs_to(:job, Job)
    has_many(:photos, Photo)
    has_many(:gallery_products, GalleryProduct)
    has_many(:albums, Album)
    has_one(:watermark, Watermark)
    embeds_one(:cover_photo, CoverPhoto, on_replace: :update)
    has_one(:organization, through: [:job, :client, :organization])
    has_one(:package, through: [:job, :package])

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
    :total_count
  ]
  @update_attrs [
    :name,
    :status,
    :expired_at,
    :password,
    :client_link_hash,
    :total_count
  ]
  @required_attrs [:name, :job_id, :status, :password]

  def create_changeset(gallery, attrs \\ %{}) do
    attrs = Map.put(attrs, :expired_at, next_year_expiration_datetime())

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
    |> validate_required([:expired_at])
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

  defp next_year_expiration_datetime do
    Date.utc_today() |> Date.add(365) |> DateTime.new!(~T[12:00:00])
  end
end
