defmodule Picsello.Cart.OrderNumberTest do
  use ExUnit.Case, async: true

  import Picsello.Cart.OrderNumber

  @base 123_456_789

  describe "number conversion" do
    test "number greater than half a base" do
      half = trunc(@base / 2)

      for i <- 1..1000 do
        number = to_number(i)
        assert number > half
      end
    end

    test "into to number to int" do
      half = trunc(@base / 2)

      number = to_number(50_000_000_000)
      int = from_number(number)

      assert number > half
      assert 50_000_000_000 = int

      number = to_number(3)
      int = from_number(number)

      assert number > half
      assert 3 = int
    end
  end

  describe "string to int" do
    test "string flow" do
      number = 12345
      string = number |> Integer.to_string()
      int = number |> from_number()

      assert ^int = from_number(string)
      assert ^number = to_number(int)
    end
  end
end
