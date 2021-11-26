defmodule Picsello.Galleries.CategoryTemplate do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "category_template" do
    field :frame_url, :string
    field :price, :integer

    timestamps()
  end

  @doc false
  def changeset(category_template, attrs) do
    category_template
    |> cast(attrs, [:frame_url, :price])
    |> validate_required([:frame_url, :price])
  end
end
