defmodule Picsello.WHCC.Shipping do
  @moduledoc "WHCC shipping options"

  @doc "Returns options available for size"
  def options(size) do
    size = normalize(size)

    all()
    |> Enum.filter(fn {_, _, frame, _} -> size |> fits?(frame) end)
  end

  def options(category, size, price) do
    all()
    |> Enum.filter(fn %{size: size_filter, category: category_filter} ->
      size_filter.(size) and category_filter.(category)
    end)
    |> Enum.sort()
    |> Enum.take(3)
    |> Enum.map(fn %{id: id, name: name, base: base, percent: percent} ->
      %{id: id, name: name, price: base + price * percent * 100}
    end)
  end

  def all(),
    do: [
      {545, "Fulfillment Shipping - Economy", {8, 12}, "3.60"},
      {1719, "Fulfillment Shipping - Economy Trackable Small Format", {8, 12}, "5.35"},
      {546, "Fulfillment Shipping - Economy Trackable", true, "7.90"},
      {100, "Fulfillment Shipping WD - 3 days or less", true, "11.25"},
      {101, "Fulfillment Shipping WD - NDS or 2 day", true, "21.60"},
      {1729, "Fulfillment Shipping WD - Priority One-Day", true, "26.95"},
      {1728, "Fulfillment Shipping WD - Standard One-Day", true, "21.60"}
      # {104, "FedEx to Canada", true}
    ]

  @doc "Converts shipping option into order attributes"
  def to_attributes(uid) when is_integer(uid),
    do: [%{"AttributeUID" => uid}, %{"AttributeUID" => 96}]

  def to_attributes({uid, _, _, _}), do: to_attributes(uid)

  defp normalize(size) do
    size
    |> String.split("x")
    |> Enum.map(&String.to_integer/1)
    |> Enum.min_max()
  end

  defp fits?({a, b}, {x, y}), do: a <= x and b <= y
  defp fits?(_, true), do: true
end
