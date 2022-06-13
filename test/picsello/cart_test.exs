defmodule Picsello.CartTest do
  use Picsello.DataCase, async: true
  import Money.Sigils
  alias Picsello.{Cart, Repo}
  alias Cart.{Order, Digital}

  defp cart_product(opts) do
    build(:cart_product,
      editor_id: Keyword.get(opts, :editor_id),
      round_up_to_nearest: 100,
      shipping_base_charge: ~M[0]USD,
      shipping_upcharge: Decimal.new(0),
      unit_markup: ~M[0]USD,
      unit_price: Keyword.get(opts, :price, ~M[100]USD),
      whcc_product: insert(:product)
    )
  end

  setup do
    Mox.verify_on_exit!()
  end

  describe "place_product" do
    setup do
      photo = insert(:photo)

      digital = %Digital{
        photo_id: photo.id,
        price: ~M[100]USD,
        preview_url: ""
      }

      [gallery: insert(:gallery), photo: photo, digital: digital]
    end

    test "creates an order and adds the digital", %{gallery: %{id: gallery_id}, digital: digital} do
      assert %Order{
               digitals: [cart_digital],
               gallery_id: ^gallery_id
             } =
               order =
               Cart.place_product(digital, gallery_id) |> Repo.preload(products: :whcc_product)

      assert Order.total_cost(order) == ~M[100]USD
      assert Map.take(cart_digital, [:photo_id, :price]) == Map.take(digital, [:photo_id, :price])
    end

    test "updates an order and adds the digital", %{
      gallery: %{id: gallery_id} = gallery,
      digital: digital
    } do
      %{id: order_id} = insert(:order, gallery: gallery)

      assert %Order{
               id: ^order_id,
               digitals: [cart_digital],
               gallery_id: ^gallery_id
             } = order = Cart.place_product(digital, gallery_id)

      assert Order.total_cost(order) == ~M[100]USD
      assert Map.take(cart_digital, [:photo_id, :price]) == Map.take(digital, [:photo_id, :price])
    end

    test "updates an order and appends the digital",
         %{
           gallery: %{id: gallery_id},
           digital: %{photo_id: digital_1_photo_id} = digital
         } do
      digital_2_photo_id = insert(:photo).id
      digital_2 = %{digital | photo_id: digital_2_photo_id}

      Cart.place_product(digital, gallery_id)

      assert %Order{
               digitals: [%{photo_id: ^digital_2_photo_id}, %{photo_id: ^digital_1_photo_id}],
               gallery_id: ^gallery_id
             } = order = Cart.place_product(digital_2, gallery_id)

      assert Order.total_cost(order) == ~M[200]USD
    end

    test "won't add the same digital twice",
         %{
           gallery: %{id: gallery_id},
           digital: digital
         } do
      order = Cart.place_product(digital, gallery_id)

      assert ~M[100]USD == order |> Repo.preload(:products) |> Order.total_cost()

      assert_raise(Ecto.ConstraintError, fn ->
        Cart.place_product(digital, gallery_id)
      end)

      assert ~M[100]USD ==
               order
               |> Repo.reload!()
               |> Repo.preload([:digitals, :products])
               |> Order.total_cost()
    end
  end

  describe "delete_product" do
    setup do
      [order: insert(:order)]
    end

    test "with an editor id and multiple products removes the product", %{order: order} do
      order =
        order
        |> Repo.preload(:products)
        |> Order.update_changeset(cart_product(editor_id: "abc", price: ~M[100]USD))
        |> Repo.update!()
        |> Repo.preload([products: :whcc_product], force: true)
        |> Order.update_changeset(cart_product(editor_id: "123", price: ~M[200]USD))
        |> Repo.update!()
        |> Repo.preload([:digitals, products: :whcc_product], force: true)

      assert {:loaded,
              %Order{
                products: [%{editor_id: "123"}]
              } = order} = Cart.delete_product(order, editor_id: "abc")

      assert Order.total_cost(order) == ~M[200]USD
    end

    test "with an editor id and multiple products and print credits reassigns print credits" do
      order =
        insert(:order,
          gallery:
            insert(:gallery,
              job:
                insert(:lead,
                  package: insert(:package, print_credits: ~M[100]USD)
                )
            )
        )

      order =
        order
        |> Repo.preload(:products)
        |> Order.update_changeset(cart_product(editor_id: "abc", price: ~M[100]USD))
        |> Repo.update!()
        |> Repo.preload([products: :whcc_product], force: true)
        |> Order.update_changeset(cart_product(editor_id: "123", price: ~M[200]USD))
        |> Repo.update!()
        |> Repo.preload([:digitals, products: :whcc_product], force: true)

      assert {:loaded,
              %Order{
                products: [%{editor_id: "123", print_credit_discount: ~M[100]USD}]
              } = order} = Cart.delete_product(order, editor_id: "abc")

      assert Order.total_cost(order) == ~M[100]USD
    end

    test "with an editor id and some digitals removes the product", %{order: order} do
      digital = %Digital{
        photo_id: insert(:photo).id,
        price: ~M[100]USD
      }

      order =
        order
        |> Repo.preload(:digitals)
        |> Order.update_changeset(digital)
        |> Repo.update!()
        |> Repo.preload(products: :whcc_product)
        |> Order.update_changeset(cart_product(editor_id: "abc", price: ~M[300]USD))
        |> Repo.update!()

      assert {:loaded,
              %Order{
                digitals: [cart_digital],
                products: []
              } = order} = Cart.delete_product(order, editor_id: "abc")

      assert Order.total_cost(order) == ~M[100]USD
      assert Map.take(cart_digital, [:photo_id, :price]) == Map.take(digital, [:photo_id, :price])
    end

    test "with an editor id and one product deletes the order", %{order: order} do
      order =
        order
        |> Repo.preload(products: :whcc_product)
        |> Order.update_changeset(cart_product(editor_id: "abc", price: ~M[300]USD))
        |> Repo.update!()

      assert {:deleted, %{id: order_id}} = Cart.delete_product(order, editor_id: "abc")
      refute Repo.get(Order, order_id)
    end

    test "with a digital id and multiple digitals removes the digital", %{order: order} do
      %{id: delete_digital_id} = insert(:digital, order: order, price: ~M[200]USD)
      %{id: remaining_digital_id} = insert(:digital, order: order, price: ~M[100]USD)

      assert {:loaded,
              %Order{
                digitals: [%{id: ^remaining_digital_id}]
              } = order} =
               order
               |> Repo.preload(:products)
               |> Cart.delete_product(digital_id: delete_digital_id)

      assert Order.total_cost(order) == ~M[100]USD
    end

    test "with a digital id and free and paid digitals removes the free digital and updates the first paid digital to free",
         %{order: order} do
      now = DateTime.utc_now()

      %{id: delete_free_digital_id} =
        insert(:digital, order: order, is_credit: true, inserted_at: now)

      %{id: remaining_digital_id_1} =
        insert(:digital, order: order, inserted_at: DateTime.add(now, 1))

      %{id: remaining_digital_id_2} =
        insert(:digital, order: order, inserted_at: DateTime.add(now, 2))

      assert {:loaded, order} =
               order
               |> Cart.delete_product(digital_id: delete_free_digital_id)

      assert [
               %{id: ^remaining_digital_id_1, is_credit: false},
               %{id: ^remaining_digital_id_2, is_credit: true}
             ] =
               order.digitals
               |> Enum.map(&Map.take(&1, [:id, :is_credit]))

      assert Order.total_cost(order) == ~M[500]USD
    end

    test "with a digital id and a product removes the digital", %{order: order} do
      digital = %Digital{
        photo_id: insert(:photo).id,
        price: ~M[100]USD,
        preview_url: ""
      }

      product = cart_product(editor_id: "abc", price: ~M[300]USD)

      %{digitals: [%{id: digital_id}]} =
        order =
        order
        |> Repo.preload(:digitals)
        |> Order.update_changeset(digital)
        |> Repo.update!()
        |> Repo.preload(:products)
        |> Order.update_changeset(product)
        |> Repo.update!()

      assert {:loaded, order} = Cart.delete_product(order, digital_id: digital_id)
      assert [%{editor_id: "abc"}] = order |> Ecto.assoc(:products) |> Repo.all()
      assert Order.total_cost(order) == ~M[300]USD
    end

    test "with a digital id and one digital the order", %{order: order} do
      %{digitals: [%{id: digital_id}]} =
        order =
        order
        |> Repo.preload(:digitals)
        |> Order.update_changeset(%Digital{
          photo_id: insert(:photo).id,
          price: ~M[100]USD,
          preview_url: ""
        })
        |> Repo.update!()
        |> Repo.preload(:products)

      assert {:deleted, %{id: order_id}} = Cart.delete_product(order, digital_id: digital_id)
      refute Repo.get(Order, order_id)
    end
  end

  describe "get_unconfirmed_order" do
    test "preloads products" do
      whcc_product = insert(:product, whcc_id: "abc")

      %{gallery_id: gallery_id} =
        insert(:order, products: build_list(1, :cart_product, whcc_product: whcc_product))

      assert {:ok, %{products: [%{whcc_product: %{whcc_id: "abc"}}]}} =
               Cart.get_unconfirmed_order(gallery_id, preload: [:products])
    end
  end

  def create_gallery(opts \\ []),
    do: insert(:gallery, job: insert(:lead, package: insert(:package, opts)))

  describe "print_credit_used" do
    def create_order(opts \\ []) do
      {total, opts} = Keyword.pop(opts, :total, ~M[0]USD)

      %{id: gallery_id} = Keyword.get_lazy(opts, :gallery, fn -> create_gallery(opts) end)

      Cart.place_product(
        build(:cart_product,
          shipping_base_charge: ~M[0]USD,
          shipping_upcharge: 0,
          unit_markup: ~M[0]USD,
          unit_price: total
        ),
        gallery_id
      )
    end

    def print_credit_used(%{products: products}),
      do: Enum.reduce(products, ~M[0]USD, &Money.add(&2, &1.print_credit_discount))

    test "zero when no print credit in package" do
      assert ~M[0]USD =
               create_order(print_credits: nil, total: ~M[1000]USD) |> print_credit_used()
    end

    test "zero when credit is used up" do
      gallery = create_gallery(print_credits: ~M[500]USD)
      create_order(gallery: gallery, total: ~M[600]USD)
      order = create_order(gallery: gallery, total: ~M[1000]USD)

      assert ~M[0]USD = print_credit_used(order)
    end

    test "order price when more credit than needed" do
      assert ~M[1000]USD =
               create_order(print_credits: ~M[1900]USD, total: ~M[1000]USD)
               |> print_credit_used()
    end

    test "order price when exactly right credit" do
      assert ~M[1000]USD =
               create_order(print_credits: ~M[1000]USD, total: ~M[1000]USD)
               |> print_credit_used()
    end

    test "remaining credit when not enough to cover order" do
      assert ~M[900]USD =
               create_order(print_credits: ~M[900]USD, total: ~M[1000]USD)
               |> print_credit_used()
    end
  end

  describe "checkout" do
    test "when no money due from client sends complete" do
      Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)
      gallery = create_gallery(download_count: 1)
      insert(:order, delivery_info: %{email: "client@example.com"}, gallery: gallery)

      order = Cart.place_product(build(:digital), gallery) |> Repo.preload([:products, :digitals])
      assert ~M[0]USD = Order.total_cost(order)
      :ok = Cart.checkout(order, helpers: PicselloWeb.Helpers)

      assert [%{errors: []}] = Picsello.FeatureCase.FeatureHelpers.run_jobs()

      assert_receive({:checkout, :complete, _order})
    end
  end
end
