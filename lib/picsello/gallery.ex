defmodule Picsello.Gallery do
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Job

  @status_options [
    values: [:draft, :active, :expired], 
    default: :draft
  ]

  schema "galleries" do
    field :name, :string
    field(:status, Ecto.Enum, @status_options) 
    field :cover_photo_id, :integer
    field :password, :string
    field :client_link_hash, :string
    field :expired_at, :utc_datetime
    belongs_to(:job, Job)

    timestamps(type: :utc_datetime)
  end

  @create_attrs [:name, :job_id, :status, :cover_photo_id, :expired_at, :password, :client_link_hash] 
  @update_attrs [:name, :status, :cover_photo_id, :expired_at, :password, :client_link_hash]  
  @required_attrs [:name, :job_id, :status]

  def create_changeset(attrs \\ %{}) do
    %__MODULE__{}
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
