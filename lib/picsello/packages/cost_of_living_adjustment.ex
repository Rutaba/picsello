defmodule Picsello.Packages.CostOfLivingAdjustment do
  @moduledoc "adjustments for each state"
  use Ecto.Schema

  @primary_key {:state, :string, []}
  schema "cost_of_living_adjustments" do
    field :multiplier, :decimal
  end
end
