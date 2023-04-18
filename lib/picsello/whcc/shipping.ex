defmodule Picsello.WHCC.Shipping do
  @moduledoc "WHCC shipping options"

  alias Picsello.Cart.Product
  @doc "Returns options available for category, size"
  def options(%{whcc_product: product, selections: selections}) do
    category = product |> Picsello.Product.whcc_category()

    %{"height" => height, "width" => width} =
      Picsello.WHCC.Product.selection_details(product, selections, category)
      |> get_in(["size", "metadata"])

    category
    |> Map.get(:name)
    |> options({height, width})
  end

  def options(category, size) do
    all()
    |> Enum.filter(fn %{size: size_filter, category: category_filter} ->
      size_filter.(size) and category_filter.(category)
    end)
  end

  defmodule Option do
    @moduledoc "Structure to represent shipping option"
    defstruct [:name, :size, :category, :attrs]
  end

  def all(),
    do: [
      %Option{
        name: "Standard loose print shipping (2-6 days)",
        size: &fits?(&1, {8, 12}),
        category: &(&1 == "Loose Prints"),
        attrs: [96, 1719]
      },
      %Option{
        name: "Standard shipping (2-6 days)",
        size: &any/1,
        category: &any/1,
        attrs: [96, 546]
      },
      %Option{
        name: "3-days shipping",
        size: &any/1,
        category: &any/1,
        attrs: [96, 100]
      },
      %Option{
        name: "2-days shipping",
        size: &any/1,
        category: &any/1,
        attrs: [96, 101]
      },
      %Option{
        name: "Economy",
        size: &fits?(&1, {8, 12}),
        category: &(&1 == "Loose Prints"),
        attrs: [96, 545]
      },
      %Option{
        name: "WD - Priority One-Day",
        size: &any/1,
        category: &any/1,
        attrs: [96, 1729]
      },
      %Option{
        name: "WD - Standard One-Day",
        size: &any/1,
        category: &any/1,
        attrs: [96, 1728]
      }
    ]

  defp any(_), do: true

  @doc "Converts shipping option into order attributes"
  def to_attributes(%Product{} = product) do
    product |> options() |> hd() |> Map.get(:attrs)
  end

  def attributes(%Product{shipping_type: type} = product) do
    case Picsello.Cart.get_base_charge(product, type) do
      [] -> to_attributes(product)
      base_charge -> [96, base_charge[:uuid]]
    end
  end

  defp fits?({a, b}, {x, y}), do: a <= x and b <= y
end
