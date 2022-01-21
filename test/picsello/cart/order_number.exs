defmodule Picsello.Cart.OrderNumberTest do
  use ExUnit.Case, async: true

  @base 123_456_789

  describe "id to number" do
    test "number greater than half a base" do
      half = trunc(@base / 2)

      number = to_number(1) |> IO.inspect()
      assert number > half

      number = to_number(2) |> IO.inspect()
      assert number > half

      number = to_number(3) |> IO.inspect()
      assert number > half

      number = to_number(4_000) |> IO.inspect()
      assert number > half

      number = to_number(50_000_000_000) |> IO.inspect()
      assert number > half
    end
  end

  @divisor 4_294_967_296

  def to_number(int) when is_integer(int) and int > 0 do
    int
    |> rem(@divisor)
    |> :binary.encode_unsigned()
    |> mangle_bits()
    |> then(fn mangled ->
      int
      |> Integer.floor_div(@divisor)
      |> then(fn head -> head * @divisor + :binary.decode_unsigned(mangled) end)
    end)
  end

  defp mangle_bits(<<x::24>>), do: mangle_bits(<<0, x>>)
  defp mangle_bits(<<x::16>>), do: mangle_bits(<<0, 0, x>>)
  defp mangle_bits(<<x::8>>), do: mangle_bits(<<0, 0, 0, x>>)

  defp mangle_bits(<<a::3, b::7, c::5, d::11, e::2, f::1, g::1, h::1, i::1>>) do
    <<
      Bitwise.bxor(b, 0b0110110)::7,
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
end
