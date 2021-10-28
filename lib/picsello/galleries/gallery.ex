defmodule Picsello.Galleries.Gallery do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Galleries.Photo, Job}

  @status_options [
    values: ~w(draft active expired),
    default: "draft"
  ]

  schema "galleries" do
    field :name, :string
    field(:status, :string, @status_options)
    field :cover_photo_url, :string
    field :cover_photo_aspect_ratio, :float
    field :password, :string
    field :client_link_hash, :string
    field :expired_at, :utc_datetime
    field :total_count, :integer

    belongs_to(:job, Job)
    has_many(:photos, Photo)
  
    timestamps(type: :utc_datetime)
  end

  @create_attrs [
    :name,
    :job_id,
    :status,
    :expired_at,
    :password,
    :client_link_hash,
    :total_count,
    :cover_photo_url,
    :cover_photo_aspect_ratio
  ]
  @update_attrs [
    :name,
    :status,
    :expired_at,
    :password,
    :client_link_hash,
    :total_count,
    :cover_photo_url,
    :cover_photo_aspect_ratio
  ]
  @required_attrs [:name, :job_id, :status]

  def create_changeset(gallery, attrs \\ %{}) do
    gallery
    |> cast(attrs, @create_attrs)
    |> validate_required(@required_attrs)
    |> validate_status(@status_options[:values])
    |> foreign_key_constraint(:job_id)
  end

  def update_changeset(gallery, attrs \\ %{}) do
    gallery
    |> cast(attrs, @update_attrs)
    |> validate_required(@required_attrs)
    |> validate_status(@status_options[:values])
  end

  defp validate_status(changeset, status_formats),
    do: validate_inclusion(changeset, :status, status_formats)
end
