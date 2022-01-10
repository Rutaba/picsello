defmodule Picsello.CategoryTemplates do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Category, Repo}

  schema "category_templates" do
    field :corners, {:array, :integer}
    field :name, :string
    field :title, :string
    field :price, Money.Ecto.Amount.Type
    belongs_to(:category, Category)

    timestamps()
  end

  def all() do
    Repo.all(__MODULE__)
  end

  @doc false
  def changeset(category_templates, attrs) do
    category_templates
    |> cast(attrs, [:name, :corners, :title])
    |> validate_required([:name, :corners, :title])
  end
end
