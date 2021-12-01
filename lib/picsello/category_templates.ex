defmodule Picsello.CategoryTemplates do
  use Ecto.Schema
  import Ecto.Changeset

  schema "category_templates" do
    field :corners, :string
    field :name, :string
    field :price, :integer
    field :category_id, :id

    timestamps()
  end

  @doc false
  def changeset(category_templates, attrs) do
    category_templates
    |> cast(attrs, [:name, :corners, :price])
    |> validate_required([:name, :corners, :price])
  end
end
