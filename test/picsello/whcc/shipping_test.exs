defmodule Picsello.WHCC.ShippingTest do
  use ExUnit.Case, async: true

  alias Picsello.WHCC.Shipping

  describe "shipping options" do
    test "have some options available" do
      assert 1 < Enum.count(Shipping.all())
    end

    test "All options available for small products" do
      options = Shipping.options("8x12")
      all = Shipping.all()

      assert Enum.count(all) == Enum.count(options)
    end

    test "Some options unavailable for huge products" do
      options = Shipping.options("10x20")
      all = Shipping.all()

      assert Enum.count(all) > Enum.count(options)
      assert 0 < Enum.count(options)
    end
  end

  describe "options into attributes" do
    test "correct attribute forming" do
      {uid, _, _} = option = Shipping.all() |> Enum.at(0)
      correct = [%{"AttributeUID" => uid}, %{"AttributeUID" => 96}] |> Enum.sort()

      assert correct == option |> Shipping.to_attributes() |> Enum.sort()
    end
  end
end
