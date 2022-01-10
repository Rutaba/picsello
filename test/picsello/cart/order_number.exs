defmodule Picsello.Cart.OrderNumberTest do
  use ExUnit.Case, async: true

  @base 123_456_789

  describe "id to number" do
    test "number greater than half a base" do
      half = trunc(@base / 2)

      for i <- 1..100_000_000 do
        assert to_number(i) > half
      end
    end
  end

  defp to_number(int) do
    int
  end
end
