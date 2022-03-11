defmodule Picsello.Galleries.Album do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset
  alias Picsello.Galleries.Gallery

  schema "albums" do
    field :name, :string
    field :password, :string
    field :set_password, :boolean

    belongs_to(:gallery, Gallery)

    timestamps(type: :utc_datetime)
  end

  @attrs [:name, :set_password, :gallery_id]

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @attrs)
    |> validate_required(@attrs)
  end
end
