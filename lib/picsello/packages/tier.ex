defmodule Picsello.Packages.Tier do
  @moduledoc "represents the level of a calculator tier"
  use Ecto.Schema

  @primary_key {:name, :string, []}
  schema "package_tiers" do
    field :position, :integer
  end
end
