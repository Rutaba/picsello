defmodule Picsello.CategoryTemplates do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.Category

  schema "category_templates" do
    field :corners, {:array, :integer}
    field :name, :string
    belongs_to(:category, Category)

    timestamps()
  end

  @doc false
  def changeset(category_templates, attrs) do
    category_templates
    |> cast(attrs, [:name, :corners])
    |> validate_required([:name, :corners])
  end
end