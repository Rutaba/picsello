defmodule Picsello.WHCC.Shipping do
  @moduledoc "WHCC shipping options"

  alias Picsello.WHCC.Shipping.Option

  @doc "Returns options available for category, size, price"
  def options(category, size, price, count \\ 3) do
    all()
    |> Enum.filter(fn %{size: size_filter, category: category_filter} ->
      size_filter.(normalize(size)) and category_filter.(category)
    end)
    |> Enum.sort_by(& &1.prio)
    |> Enum.take(count)
    |> Enum.map(fn %{id: id, name: name, base: base, percent: percent} ->
      %{id: id, name: name, price: Money.add(base, Money.multiply(price, percent / 100))}
    end)
  end

  defmodule Option do
    @moduledoc "Structure to represent shipping option"
    defstruct [:id, :name, :base, :percent, :size, :category, :attrs, :prio]
  end

  def all(),
    do: [
      %Option{
        id: 1,
        name: "Economy",
        base: Money.new(355),
        percent: 5,
        size: &fits?(&1, {8, 12}),
        category: &(&1 == "Loose Prints"),
        attrs: [96, 545],
        prio: 5
      },
      %Option{
        id: 2,
        name: "Economy Trackable Small Format",
        base: Money.new(535),
        percent: 6,
        size: &fits?(&1, {8, 12}),
        category: &(&1 == "Loose Prints"),
        attrs: [96, 1719],
        prio: 1
      },
      %Option{
        id: 3,
        name: "Economy Trackable",
        base: Money.new(790),
        percent: 9,
        size: &any/1,
        category: &any/1,
        attrs: [96, 546],
        prio: 2
      },
      %Option{
        id: 4,
        name: "WD - 3 days or less",
        base: Money.new(1125),
        percent: 10,
        size: &any/1,
        category: &any/1,
        attrs: [96, 100],
        prio: 3
      },
      %Option{
        id: 5,
        name: "WD - NDS or 2 day",
        base: Money.new(2160),
        percent: 15,
        size: &any/1,
        category: &any/1,
        attrs: [96, 101],
        prio: 4
      },
      %Option{
        id: 6,
        name: "WD - Priority One-Day",
        base: Money.new(2695),
        percent: 15,
        size: &any/1,
        category: &any/1,
        attrs: [96, 1729],
        prio: 5
      },
      %Option{
        id: 7,
        name: "WD - Standard One-Day",
        base: Money.new(2160),
        percent: 15,
        size: &any/1,
        category: &any/1,
        attrs: [96, 1728],
        prio: 5
      },
      %Option{
        id: 8,
        name: "new one",
        base: Money.new(750),
        percent: 0,
        size: &any/1,
        category: &(&1 in ["Albums", "Books"]),
        attrs: [553, 548],
        prio: 1
      }
    ]

  defp any(_), do: true

  @doc "Converts shipping option into order attributes"
  def to_attributes(id) when is_integer(id) do
    all()
    |> Enum.find(%{attrs: []}, &(&1.id == id))
    |> then(& &1.attrs)
    |> Enum.map(&%{"AttributeUID" => &1})
  end

  defp normalize(size) do
    size
    |> String.split("x")
    |> Enum.map(&String.to_integer/1)
    |> Enum.min_max()
  end

  defp fits?({a, b}, {x, y}), do: a <= x and b <= y
end
