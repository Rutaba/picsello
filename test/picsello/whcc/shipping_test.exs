defmodule Picsello.WHCC.ShippingTest do
  use Picsello.DataCase, async: true

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
      assert [96, 546] =
               Shipping.to_attributes(build(:cart_product, whcc_product: insert(:product)))
    end
  end
end
