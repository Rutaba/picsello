defmodule Picsello.WHCC.ShippingTest do
  use ExUnit.Case, async: true

  alias Picsello.WHCC.Shipping

  describe "shipping options" do
    test "have some options available" do
      assert 1 < Enum.count(Shipping.all())
    end

    test "All options available for small products" do
      options = Shipping.options("Loose Prints", "8x12", Money.new(100), 30)
      all = Shipping.all()

      assert Enum.count(all) - 1 == Enum.count(options)
    end

    test "Loose Print shipping price" do
      options = Shipping.options("Loose Prints", "8x8", Money.new(100), 1)

      correct = Money.new(541)
      assert [%{id: 2, price: ^correct}] = options
    end

    test "Some options unavailable for huge products" do
      options = Shipping.options("Loose Prints", "10x20", Money.new(100), 30)
      all = Shipping.all()

      assert Enum.count(all) > Enum.count(options)
      assert 0 < Enum.count(options)
    end
  end

  describe "options into attributes" do
    test "correct attribute forming" do
      %Shipping.Option{id: id} = Shipping.all() |> Enum.at(0)
      correct = [%{"AttributeUID" => 545}, %{"AttributeUID" => 96}] |> Enum.sort()

      assert correct == Shipping.to_attributes(id) |> Enum.sort()
    end
  end
end
