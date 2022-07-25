defmodule Picsello.Cart.OrderDeliveryInfoTest do
  use Picsello.DataCase, async: true
  alias Picsello.Cart

  describe "changesets casting" do
    test "valid struct without address casted" do
      changeset = Cart.delivery_info_change(%{name: "David", email: "david@mail.ua"})

      assert changeset.valid?
    end

    test "works with google places" do
      changeset =
        Cart.delivery_info_change(%{
          "name" => "David",
          "email" => "david@mail.ua",
          "address" => %{}
        })

      refute changeset.valid?

      changeset =
        Cart.delivery_info_change(changeset, %{
          "address_components" => [
            %{"short_name" => "123", "types" => ["street_number"]},
            %{"short_name" => "main st", "types" => ["route"]},
            %{"short_name" => "Chicago", "types" => ["locality"]},
            %{"short_name" => "IL", "types" => ["administrative_area_level_1"]},
            %{"short_name" => "60661", "types" => ["postal_code"]}
          ]
        })

      assert changeset.valid?
    end
  end
end
