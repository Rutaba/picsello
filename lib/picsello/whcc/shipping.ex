defmodule Picsello.WHCC.Shipping do
  @moduledoc "WHCC shipping options"

  @doc "Returns options available for size"
  def options(size) do
    size = normalize(size)

    all()
    |> Enum.filter(fn {_, _, frame, _} -> size |> fits?(frame) end)
  end

  def all(),
    do: [
      {545, "Economy USPS ", {8, 12}, "3.60"},
      {1719, "Small Economy Trackable ", {8, 12}, "5.35"},
      {546, "Economy trackable ", true, "7.90"},
      {100, "3 days or less  ", true, "11.25"},
      {101, "Next day saver ", true, "21.60"},
      {1729, "Priority One-Day", true, "26.95"},
      {1728, "Standard One-Day", true, "21.60"}
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
