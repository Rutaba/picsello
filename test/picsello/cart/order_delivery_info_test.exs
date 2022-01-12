defmodule Picsello.Cart.OrderDeliveryInfoTest do
  use Picsello.DataCase, async: true
  alias Picsello.Cart

  describe "changesets casting" do
    test "valid struct without address casted" do
      changeset = Cart.delivery_info_change(%{name: "David", email: "david@mail.ua"})
      
      assert changeset.valid?
    end

    test "city and state depend on zip code" do
      changeset = Cart.delivery_info_change(%{name: "David", email: "david@mail.ua", address: %{addr1: "Universitetska 12", city: "New York", state: "NY", zip: "10001"}})
      changeset2 = Cart.delivery_info_change(%{name: "David", email: "david@mail.ua", address: %{addr1: "Universitetska 12", city: "New York", state: "LA", zip: "10001"}})
      changeset3 = Cart.delivery_info_change(%{name: "David", email: "david@mail.ua", address: %{addr1: "Universitetska 12", city: "Boston", state: "NY", zip: "10001"}})
      
      assert changeset.valid?
      assert %{address: %{state: ["do not fit the zip"]}} = errors_on(changeset2)
      assert %{address: %{city: ["do not fit the zip"]}} = errors_on(changeset3)
    end
  end


end
