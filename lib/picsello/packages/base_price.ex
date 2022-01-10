defmodule Picsello.Packages.BasePrice do
  @moduledoc "the base prices to use for initial package templates"
  use Ecto.Schema

  schema "package_base_prices" do
    field :tier, :string
    field :job_type, :string
    field :full_time, :boolean
    field :min_years_experience, :integer
    field :base_price, Money.Ecto.Amount.Type
    field :shoot_count, :integer
    field :download_count, :integer
  end
end
