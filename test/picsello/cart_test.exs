defmodule Picsello.CartTest do
  use Picsello.DataCase, async: true
  import Money.Sigils
  alias Picsello.Cart
  alias Cart.{Order, Digital}
  alias Cart.Product, as: CartProduct

  defp cart_product(opts) do
    build(:cart_product,
      editor_id: Keyword.get(opts, :editor_id),
      shipping_base_charge: ~M[1000]USD,
      shipping_upcharge: Decimal.new(0),
      unit_markup: ~M[0]USD,
      unit_price: Keyword.get(opts, :price, ~M[100]USD),
      whcc_product: Keyword.get_lazy(opts, :whcc_product, fn -> insert(:product) end)
    )
  end

  defp insert_gallery(%{package: package}) do
    gallery = insert(:gallery, job: insert(:lead, package: package)) |> Map.put(:credits_available, true)
    gallery_digital_pricing = insert(:gallery_digital_pricing, gallery: gallery)
    [gallery: gallery, gallery_digital_pricing: gallery_digital_pricing]
  end

  defp insert_gallery(ctx), do: ctx |> Map.put(:package, build(:package)) |> insert_gallery()

  defp insert_order(%{gallery: gallery}) do
    gallery_client = insert(:gallery_client, %{email: "testing@picsello.com", gallery_id: gallery.id})
    [order: insert(:order, gallery: gallery, gallery_client: gallery_client)]
  end

  setup do
    Mox.verify_on_exit!()
  end

  def check_out(order) do
    Picsello.MockWHCCClient
    |> Mox.stub(:editors_export, fn _, _, _ -> build(:whcc_editor_export) end)
    |> Mox.stub(:create_order, fn _, _ -> {:ok, build(:whcc_order_created)} end)

    Picsello.MockPayments
    |> Mox.stub(:create_session, fn _, _ -> {:ok, build(:stripe_session, id: "expire-me")} end)
    |> Mox.stub(:retrieve_payment_intent, fn _, _ -> {:ok, build(:stripe_payment_intent)} end)

    {:ok, order} =
      Cart.store_order_delivery_info(
        order,
        Cart.delivery_info_change(order, %{
          address: %{state: "IL", zip: "60661", addr1: "661 w lake", city: "Chicago"},
          name: "brian",
          email: "brian@example.com"
        })
      )

    Picsello.Cart.Checkouts.check_out(order.id, %{"success_url" => "", "cancel_url" => ""})
  end

  def expect_expire_session() do
    Mox.expect(Picsello.MockPayments, :expire_session, fn "expire-me", _ ->
      {:ok, build(:stripe_session, status: "expired")}
    end)
  end

  describe "place_product - while checking out" do
    setup :insert_gallery

    test "expires previous stripe session", %{gallery: gallery} do
      product = build(:cart_product)
      gallery_client = insert(:gallery_client, %{email: "testing@picsello.com", gallery_id: gallery.id})
      order =
        product
        |> Cart.place_product(gallery, gallery_client)
        |> then(fn order ->
          products = Cart.add_default_shipping_to_products(order)
          Map.put(order, :products, products)
        end)

      check_out(order)

      expect_expire_session()

      Cart.place_product(product, gallery, gallery_client)
    end
  end

  describe "place_product - whcc" do
    setup do
      [package: insert(:package, print_credits: ~M[100000]USD)]
    end

    setup :insert_gallery

    test "second product also uses print credits", %{gallery: gallery} do
      gallery_client = insert(:gallery_client, %{email: "testing@picsello.com", gallery_id: gallery.id})
      for product <- build_list(2, :cart_product) do
        Cart.place_product(product, gallery, gallery_client)
      end

      assert [
               %{print_credit_discount: ~M[10]USD},
               %{print_credit_discount: ~M[0]USD}
             ] = Repo.all(CartProduct)
    end

    test "updated product reclaims credits", %{gallery: gallery} do
      gallery_client = insert(:gallery_client, %{email: "testing@picsello.com", gallery_id: gallery.id})
      for quantity <- [1, 2] do
        build(:cart_product, quantity: quantity, editor_id: "editor-id")
        |> Cart.place_product(gallery, gallery_client)
      end

      assert [
               %{print_credit_discount: ~M[10]USD}
             ] = Repo.all(CartProduct)
    end
  end

  describe "place_product - digital" do
    setup do
      photo = insert(:photo)

      digital = %Digital{
        photo_id: photo.id,
        price: ~M[100]USD,
        preview_url: ""
      }

      [package: insert(:package), photo: photo, digital: digital]
    end

    setup :insert_gallery

    test "creates an order and adds the digital", %{gallery: %{id: gallery_id} = gallery, digital: digital} do
      gallery_client = insert(:gallery_client, %{email: "testing@picsello.com", gallery_id: gallery.id})
      assert %Order{
               digitals: [cart_digital],
               gallery_id: ^gallery_id
             } =
               order =
               Cart.place_product(digital, gallery, gallery_client) |> Repo.preload(products: :whcc_product)

      assert Order.total_cost(order) == ~M[0]USD
      assert Map.take(cart_digital, [:photo_id, :price]) == Map.take(digital, [:photo_id, :price])
    end

    test "updates an order and adds the digital", %{
      gallery: %{id: gallery_id} = gallery,
      digital: digital
    } do
      gallery_client = insert(:gallery_client, %{email: "testing@picsello.com", gallery_id: gallery.id})
      %{id: order_id} = insert(:order, gallery: gallery, gallery_client: gallery_client)

      assert %Order{
               id: ^order_id,
               digitals: [cart_digital],
               gallery_id: ^gallery_id
             } = order = Cart.place_product(digital, gallery, gallery_client)

      assert Order.total_cost(order) == ~M[0]USD
      assert Map.take(cart_digital, [:photo_id, :price]) == Map.take(digital, [:photo_id, :price])
    end

    test "updates an order and appends the digital",
         %{
           gallery: %{id: gallery_id} = gallery,
           digital: %{photo_id: digital_1_photo_id} = digital
         } do
      digital_2_photo_id = insert(:photo).id
      digital_2 = %{digital | photo_id: digital_2_photo_id}
      gallery_client = insert(:gallery_client, %{email: "testing@picsello.com", gallery_id: gallery.id})
      Cart.place_product(digital, gallery, gallery_client)

      assert %Order{
               digitals: [%{photo_id: ^digital_2_photo_id}, %{photo_id: ^digital_1_photo_id}],
               gallery_id: ^gallery_id
             } = order = Cart.place_product(digital_2, gallery, gallery_client)

      assert Order.total_cost(order) == ~M[0]USD
    end

    test "won't add the same digital twice",
         %{
           gallery: %{id: gallery_id} = gallery,
           digital: digital
         } do
      gallery_client = insert(:gallery_client, %{email: "testing@picsello.com", gallery_id: gallery_id})
      order = Cart.place_product(digital, gallery, gallery_client)

      assert ~M[0]USD == order |> Repo.preload(:products) |> Order.total_cost()

      assert_raise(Ecto.ConstraintError, fn ->
        Cart.place_product(digital, gallery, gallery_client)
      end)

      assert ~M[0]USD ==
               order
               |> Repo.reload!()
               |> Repo.preload([:digitals, :products])
               |> Order.total_cost()
    end
  end

  describe "delete_product - editor id and multiple products" do
    setup do
      [package: insert(:package, print_credits: ~M[10000]USD)]
    end

    setup :insert_gallery

    test "with an editor id and multiple products and print credits reassigns print credits", %{
      gallery: gallery
    } do
      gallery_client = insert(:gallery_client, %{email: "testing@picsello.com", gallery_id: gallery.id})
      assert %{print: ~M[10]USD} = Cart.credit_remaining(gallery)
      whcc_product = insert(:product)

      order =
        for opts <- [
              [editor_id: "123", price: ~M[6500]USD],
              [editor_id: "abc", price: ~M[6500]USD]
            ],
            reduce: nil do
          _ ->
            opts
            |> Keyword.put(:whcc_product, whcc_product)
            |> cart_product()
            |> Cart.place_product(gallery, gallery_client)
        end

      assert Order.total_cost(order) == ~M[14990]USD

      assert {:loaded,
              %Order{
                products: [%{editor_id: "123", print_credit_discount: ~M[10]USD}]
              }} = Cart.delete_product(order, gallery, editor_id: "abc")
    end
  end

  describe "delete_product" do
    setup do
      [package: insert(:package)]
    end

    setup [:insert_gallery, :insert_order]

    test "with a previous checkout attempt expires previous session", %{order: order, gallery: gallery} do
      order
      |> Repo.preload(:products)
      |> Order.update_changeset(cart_product(editor_id: "abc", price: ~M[100]USD))
      |> Repo.update!()
      |> then(fn order ->
        products = Cart.add_default_shipping_to_products(order)
        Map.put(order, :products, products)
      end)

      check_out(order)

      expect_expire_session()

      Cart.delete_product(order, gallery, editor_id: "abc")
    end

    test "with an editor id and multiple products removes the product", %{order: order, gallery: gallery} do
      order
      |> Repo.preload(:products)
      |> Order.update_changeset(cart_product(editor_id: "abc", price: ~M[100]USD))
      |> Repo.update!()
      |> Repo.preload([products: :whcc_product], force: true)
      |> Order.update_changeset(cart_product(editor_id: "123", price: ~M[200]USD))
      |> Repo.update!()

      assert {:loaded,
              %Order{
                products: [%{editor_id: "123"}]
              } = order} = Cart.delete_product(order, gallery, editor_id: "abc")

      assert Order.total_cost(order) == ~M[1190]USD
    end

    test "with an editor id and some digitals removes the product", %{order: order, gallery: gallery} do
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
              } = order} = Cart.delete_product(order, gallery, editor_id: "abc")

      assert Order.total_cost(order) == ~M[100]USD
      assert Map.take(cart_digital, [:photo_id, :price]) == Map.take(digital, [:photo_id, :price])
    end

    test "with an editor id and one product deletes the order", %{order: order, gallery: gallery} do
      order =
        order
        |> Repo.preload(products: :whcc_product)
        |> Order.update_changeset(cart_product(editor_id: "abc", price: ~M[300]USD))
        |> Repo.update!()

      assert {:deleted, %{id: order_id}} = Cart.delete_product(order, gallery, editor_id: "abc")
      refute Repo.get(Order, order_id)
    end

    test "with a digital id and multiple digitals removes the digital", %{order: order, gallery: gallery} do
      %{id: delete_digital_id} = insert(:digital, order: order, price: ~M[200]USD)
      %{id: remaining_digital_id} = insert(:digital, order: order, price: ~M[100]USD)

      assert {:loaded,
              %Order{
                digitals: [%{id: ^remaining_digital_id}]
              } = order} =
               order
               |> Repo.preload(:products)
               |> Cart.delete_product(gallery, digital_id: delete_digital_id)

      assert Order.total_cost(order) == ~M[100]USD
    end

    test "with a digital id and free and paid digitals removes the free digital and updates the first paid digital to free",
         %{order: order, gallery: gallery} do
      now = DateTime.utc_now()

      %{id: delete_free_digital_id} =
        insert(:digital, order: order, is_credit: true, inserted_at: now)

      %{id: remaining_digital_id_1} =
        insert(:digital, order: order, inserted_at: DateTime.add(now, 1))

      %{id: remaining_digital_id_2} =
        insert(:digital, order: order, inserted_at: DateTime.add(now, 2))

      assert {:loaded, order} =
               order
               |> Cart.delete_product(gallery, digital_id: delete_free_digital_id)

      assert [
               %{id: ^remaining_digital_id_1, is_credit: false},
               %{id: ^remaining_digital_id_2, is_credit: true}
             ] =
               order.digitals
               |> Enum.map(&Map.take(&1, [:id, :is_credit]))

      assert Order.total_cost(order) == ~M[500]USD
    end

    test "with a digital id and a product removes the digital", %{order: order, gallery: gallery} do
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

      assert {:loaded, order} = Cart.delete_product(order, gallery, digital_id: digital_id)
      assert [%{editor_id: "abc"}] = order |> Ecto.assoc(:products) |> Repo.all()
      assert Order.total_cost(order) == ~M[1300]USD
    end

    test "with a digital id and one digital the order", %{order: order, gallery: gallery} do
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

      assert {:deleted, %{id: order_id}} = Cart.delete_product(order, gallery, digital_id: digital_id)
      refute Repo.get(Order, order_id)
    end
  end

  describe "get_unconfirmed_order" do
    test "preloads products" do
      whcc_product = insert(:product, whcc_id: "abc")
      gallery = insert(:gallery)
      gallery_client = insert(:gallery_client, %{email: "testing@picsello.com", gallery_id: gallery.id})
      %{gallery_id: gallery_id} =
        insert(:order, gallery: gallery, gallery_client: gallery_client, products: build_list(1, :cart_product, whcc_product: whcc_product))

      assert {:ok, %{products: [%{whcc_product: %{whcc_id: "abc"}}]}} =
               Cart.get_unconfirmed_order(gallery_id, gallery_client_id: gallery_client.id, preload: [:products])
    end
  end

  def create_gallery(opts \\ []) do
    gallery = insert(:gallery, job: insert(:lead, package: insert(:package, opts))) |> Map.put(:credits_available, true)
    insert(:gallery_digital_pricing, gallery: gallery)
    gallery |> Repo.preload(:gallery_digital_pricing)
  end

  describe "print_credit_used" do
    def create_order(opts \\ []) do
      {total, opts} = Keyword.pop(opts, :total, ~M[0]USD)

      gallery = Keyword.get_lazy(opts, :gallery, fn -> create_gallery(opts) end)
      gallery_client = insert(:gallery_client, %{email: "testing@picsello.com", gallery_id: gallery.id})
      Cart.place_product(
        build(:cart_product,
          shipping_base_charge: ~M[0]USD,
          shipping_upcharge: 0,
          unit_markup: ~M[0]USD,
          unit_price: total
        ),
        gallery,
        gallery_client
      )
    end

    def print_credit_used(%{products: products}),
      do: Enum.reduce(products, ~M[0]USD, &Money.add(&2, &1.print_credit_discount))

    test "zero when no print credit in package" do
      assert ~M[10]USD =
               create_order(print_credits: nil, total: ~M[1000]USD) |> print_credit_used()
    end

    test "zero when credit is used up" do
      gallery = create_gallery(print_credits: ~M[500]USD)

      create_order(gallery: gallery, total: ~M[600]USD)
      |> Order.placed_changeset()
      |> Repo.update!()

      assert %{print: ~M[0]USD} = Cart.credit_remaining(gallery)
      order = create_order(gallery: gallery, total: ~M[1000]USD)

      assert ~M[0]USD = print_credit_used(order)
    end

    test "order price when more credit than needed" do
      assert ~M[10]USD =
               create_order(print_credits: ~M[1000]USD, total: ~M[1000]USD)
               |> print_credit_used()
    end

    test "order price when exactly right credit" do
      assert ~M[10]USD =
               create_order(print_credits: ~M[1000]USD, total: ~M[1000]USD)
               |> print_credit_used()
    end

    test "remaining credit when not enough to cover order" do
      assert ~M[10]USD =
               create_order(print_credits: ~M[900]USD, total: ~M[1000]USD)
               |> print_credit_used()
    end
  end

  describe "checkout" do
    test "when no money due from client sends complete" do
      Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)
      gallery = create_gallery(download_count: 1)
      gallery_client = insert(:gallery_client, %{email: "testing@picsello.com", gallery_id: gallery.id})
      insert(:order, delivery_info: %{name: "abc", email: "client@example.com"}, gallery: gallery, gallery_client: gallery_client)

      order = Cart.place_product(build(:digital), gallery, gallery_client) |> Repo.preload([:products, :digitals])
      assert ~M[0]USD = Order.total_cost(order)
      :ok = Cart.checkout(order, helpers: PicselloWeb.Helpers)

      assert [%{errors: []}] = Picsello.FeatureCase.FeatureHelpers.run_jobs()

      assert_receive({:checkout, :complete, _order})
    end
  end

  describe "delivery_info_change" do
    test "requires address when order includes products" do
      gallery = insert(:gallery) |> Map.put(:credits_available, true)
      gallery_client = insert(:gallery_client, %{email: "testing@picsello.com", gallery_id: gallery.id})
      order = Cart.place_product(build(:cart_product), gallery, gallery_client)

      changeset = Cart.delivery_info_change(order)

      refute changeset.valid?

      assert [_] = Keyword.get_values(changeset.errors, :address)
    end

    test "does not require address when order is only digitals" do
      gallery = insert(:gallery) |> Map.put(:credits_available, true)
      gallery_client = insert(:gallery_client, %{email: "testing@picsello.com", gallery_id: gallery.id})
      order = Cart.place_product(build(:digital), gallery, gallery_client)

      changeset = Cart.delivery_info_change(order)

      refute changeset.valid?

      assert [] = Keyword.get_values(changeset.errors, :address)
    end
  end
end
