defmodule Picsello.Galleries.Gallery do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Galleries.{Photo, Watermark}
  alias Picsello.Job

  @status_options [
    values: ~w(draft active expired),
    default: "draft"
  ]

  schema "galleries" do
    field :name, :string
    field(:status, :string, @status_options)
    field :cover_photo_id, :string
    field :cover_photo_aspect_ratio, :float
    field :password, :string
    field :client_link_hash, :string
    field :expired_at, :utc_datetime
    field :total_count, :integer

    belongs_to(:job, Job)
    has_many(:photos, Photo)
    has_one(:watermark, Watermark)

    timestamps(type: :utc_datetime)
  end

  @create_attrs [
    :name,
    :job_id,
    :status,
    :expired_at,
    :client_link_hash,
    :total_count,
    :cover_photo_id,
    :cover_photo_aspect_ratio
  ]
  @update_attrs [
    :name,
    :status,
    :expired_at,
    :password,
    :client_link_hash,
    :total_count,
    :cover_photo_id,
    :cover_photo_aspect_ratio
  ]
  @required_attrs [:name, :job_id, :status, :password]

  def create_changeset(gallery, attrs \\ %{}) do
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

  def generate_password, do: Enum.random(100_000..999_999) |> to_string

  defp cast_password(changeset),
    do: put_change(changeset, :password, generate_password())

  defp validate_status(changeset, status_formats),
    do: validate_inclusion(changeset, :status, status_formats)

  defp validate_name(changeset),
    do: validate_length(changeset, :name, max: 50)
end
