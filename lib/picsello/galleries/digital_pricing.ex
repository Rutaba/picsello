defmodule Picsello.Galleries.DigitalPricing do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Picsello.Package

  @primary_key false
  embedded_schema do
    field :download_each_price, Money.Ecto.Amount.Type
    field :download_count, :integer
    field :print_credits, Money.Ecto.Amount.Type
    field :buy_all, Money.Ecto.Amount.Type
  end

  @create_attrs [:download_each_price, :download_count, :print_credits, :buy_all]
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @create_attrs)
    |> validate_required(~w[download_count download_each_price]a)
    |> validate_number(:download_count, greater_than_or_equal_to: 0)
    |> Package.validate_money(:download_each_price)
    |> Package.validate_money(:print_credits,
      greater_than_or_equal_to: 0,
      message: "must be equal to or less than total price"
    )
  end
end
