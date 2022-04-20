defmodule Picsello.WHCC.ShippingTest do
  use ExUnit.Case, async: true

  alias Picsello.WHCC.Shipping

  describe "shipping options" do
    test "have some options available" do
      assert 1 < Enum.count(Shipping.all())
    end

    test "All options available for small products" do
      options = Shipping.options("Loose Prints", {8, 12})
      all = Shipping.all()

      assert Enum.count(all) == Enum.count(options)
    end

    test "Some options unavailable for huge products" do
      options = Shipping.options("Loose Prints", {10, 20})
      all = Shipping.all()

      assert Enum.count(all) > Enum.count(options)
      assert 0 < Enum.count(options)
    end
  end

  describe "options into attributes" do
    test "correct attribute forming" do
      assert [%{"AttributeUID" => 1719}, %{"AttributeUID" => 96}] =
               Shipping.to_attributes(%{attrs: [1719, 96]})
    end
  end
end
