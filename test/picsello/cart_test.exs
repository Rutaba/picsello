defmodule Picsello.CartTest do
  use Picsello.DataCase, async: true
  import Money.Sigils

  describe "place_product" do
    setup do
      photo = insert(:photo)

      digital = %Picsello.Cart.Order.Digital{
        photo_id: photo.id,
        price: ~M[100]USD,
        preview_url: ""
      }

      [gallery: insert(:gallery), photo: photo, digital: digital]
    end

    test "creates an order and adds the digital", %{gallery: %{id: gallery_id}, digital: digital} do
      assert %Picsello.Cart.Order{
               subtotal_cost: ~M[100]USD,
               digitals: [cart_digital],
               gallery_id: ^gallery_id
             } = Picsello.Cart.place_product(digital, gallery_id)

      assert Map.take(cart_digital, [:photo_id, :price]) == Map.take(digital, [:photo_id, :price])
    end

    test "updates an order and adds the digital", %{
      gallery: %{id: gallery_id} = gallery,
      digital: digital
    } do
      %{id: order_id} = insert(:order, gallery: gallery)

      assert %Picsello.Cart.Order{
               id: ^order_id,
               subtotal_cost: ~M[100]USD,
               digitals: [cart_digital],
               gallery_id: ^gallery_id
             } = Picsello.Cart.place_product(digital, gallery_id)

      assert Map.take(cart_digital, [:photo_id, :price]) == Map.take(digital, [:photo_id, :price])
    end

    test "updates an order and appends the digital",
         %{
           gallery: %{id: gallery_id},
           digital: %{photo_id: digital_1_photo_id} = digital
         } do
      digital_2_photo_id = insert(:photo).id
      digital_2 = %{digital | photo_id: digital_2_photo_id}

      Picsello.Cart.place_product(digital, gallery_id)

      assert %Picsello.Cart.Order{
               subtotal_cost: ~M[200]USD,
               digitals: [%{photo_id: ^digital_2_photo_id}, %{photo_id: ^digital_1_photo_id}],
               gallery_id: ^gallery_id
             } = Picsello.Cart.place_product(digital_2, gallery_id)
    end

    test "won't add the same digital twice",
         %{
           gallery: %{id: gallery_id},
           digital: %{photo_id: digital_1_photo_id} = digital
         } do
      Picsello.Cart.place_product(digital, gallery_id)

      assert %Picsello.Cart.Order{
               subtotal_cost: ~M[100]USD,
               digitals: [%{photo_id: ^digital_1_photo_id}],
               gallery_id: ^gallery_id
             } = Picsello.Cart.place_product(digital, gallery_id)
    end
  end
end
