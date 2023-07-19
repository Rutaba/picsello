defmodule Picsello.Packages.BasePrice do
  @moduledoc "the base prices to use for initial package templates"
  use Ecto.Schema

  schema "package_base_prices" do
    field :base_price, Money.Ecto.Map.Type
    field :print_credits, Money.Ecto.Map.Type
    field :buy_all, Money.Ecto.Map.Type
    field :description, :string
    field :download_count, :integer
    field :full_time, :boolean
    field :job_type, :string
    field :min_years_experience, :integer
    field :shoot_count, :integer
    field :max_session_per_year, :integer
    field :tier, :string
    field :turnaround_weeks, :integer
  end
end
