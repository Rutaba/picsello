defmodule Picsello.Galleries.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :name, :string
    field :corners, {:array, {:array, :integer}}
    field :template_image_url, :string
    
    timestamps(type: :utc_datetime)
  end

  @attrs [:name, :corners, :template_image_url]
  
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @attrs)
    |> validate_required(@attrs)
  end
end
