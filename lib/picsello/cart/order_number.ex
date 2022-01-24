defmodule Picsello.Cart.OrderNumber do
  @moduledoc "Converts int to number and vice versa"

  @divisor 4_294_967_296

  def to_number(string) when is_binary(string),
    do:
      string
      |> String.to_integer()
      |> to_number()

  def to_number(int, mangler \\ &mangle_bits/1) when is_integer(int) and int > 0 do
    int
    |> rem(@divisor)
    |> :binary.encode_unsigned()
    |> pad_bits()
    |> then(mangler)
    |> then(fn mangled ->
      int
      |> Integer.floor_div(@divisor)
      |> then(fn head -> head * @divisor + :binary.decode_unsigned(mangled) end)
    end)
  end

  def from_number(string) when is_binary(string),
    do:
      string
      |> String.to_integer()
      |> from_number()

  def from_number(number), do: to_number(number, &demangle_bits/1)

  defp pad_bits(<<x, y, z>>), do: pad_bits(<<0, x, y, z>>)
  defp pad_bits(<<x, y>>), do: pad_bits(<<0, 0, x, y>>)
  defp pad_bits(<<x>>), do: pad_bits(<<0, 0, 0, x>>)
  defp pad_bits(x), do: x

  defp mangle_bits(<<a::3, b::7, c::5, d::11, e::2, f::1, g::1, h::1, i::1>>) do
    <<
      Bitwise.bxor(b, 0b0000110)::7,
      i::1,
      Bitwise.bxor(d, 0b10010010011)::11,
      h::1,
      Bitwise.bxor(a, 0b110)::3,
      g::1,
      Bitwise.bxor(e, 0b01)::2,
      f::1,
      Bitwise.bxor(c, 0b10101)::5
    >>
  end

  defp demangle_bits(<<b::7, i::1, d::11, h::1, a::3, g::1, e::2, f::1, c::5>>) do
    <<
      Bitwise.bxor(a, 0b110)::3,
      Bitwise.bxor(b, 0b0000110)::7,
      Bitwise.bxor(c, 0b10101)::5,
      Bitwise.bxor(d, 0b10010010011)::11,
      Bitwise.bxor(e, 0b01)::2,
      f::1,
      g::1,
      h::1,
      i::1
    >>
  end
end
