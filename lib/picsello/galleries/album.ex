defmodule Picsello.Galleries.Album do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset
  alias Picsello.Galleries.Gallery
  alias Picsello.Galleries.Photo

  schema "albums" do
    field :name, :string
    field :password, :string
    field :set_password, :boolean

    belongs_to(:gallery, Gallery)
    has_many(:photo, Photo)

    timestamps(type: :utc_datetime)
  end

  @attrs [:name, :set_password, :gallery_id, :password]
  @required_attrs [:name, :set_password, :gallery_id]

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @attrs)
    |> validate_required(@required_attrs)
  end

  def update_changeset(struct, attrs \\ %{}) do
    struct
    |> cast(attrs, [:name, :set_password, :password])
  end
end
