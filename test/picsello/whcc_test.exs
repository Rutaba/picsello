defmodule Picsello.WHCCTest do
  use Picsello.DataCase

  def read_fixture(path) do
    "test/support/fixtures/whcc/api/v1"
    |> Path.join("#{path}.json")
    |> File.read!()
    |> Jason.decode!()
  end

  setup do
    Picsello.MockWHCCClient
    |> Mox.stub(:products, fn -> [] end)
    |> Mox.stub(:product_details, &%{&1 | attribute_categories: [], api: %{}})
    |> Mox.stub(:designs, fn -> [] end)
    |> Mox.stub(:design_details, & &1)

    :ok
  end

  describe "sync() - categories" do
    setup do
      Picsello.MockWHCCClient
      |> Mox.stub(:products, fn ->
        [
          %Picsello.WHCC.Product{
            id: "product-id",
            name: "jeans",
            category: %Picsello.WHCC.Category{id: "abc", name: "pants"}
          }
        ]
      end)

      :ok
    end

    test "adds new categories" do
      Picsello.WHCC.sync()

      assert [%Picsello.Category{whcc_id: "abc", whcc_name: "pants"}] =
               Repo.all(Picsello.Category)
    end

    test "updates existing categories" do
      insert(:category, whcc_id: "abc", whcc_name: "socks")

      Picsello.WHCC.sync()

      assert [%Picsello.Category{whcc_id: "abc", whcc_name: "pants"}] =
               Repo.all(Picsello.Category)
    end

    test "removes existing categories" do
      insert(:category, whcc_id: "123", whcc_name: "socks")

      Picsello.WHCC.sync()

      assert [
               %Picsello.Category{whcc_id: "abc", whcc_name: "pants", deleted_at: nil},
               %Picsello.Category{whcc_id: "123", whcc_name: "socks", deleted_at: %DateTime{}}
             ] = Repo.all(from(Picsello.Category, order_by: :whcc_name))
    end
  end

  describe "sync() - designs" do
    def whcc_product_id(), do: "product-with-designs"

    setup do
      Picsello.MockWHCCClient
      |> Mox.stub(:designs, fn ->
        "designs"
        |> read_fixture()
        |> Enum.map(
          &(&1
            |> put_in(["product", "_id"], whcc_product_id())
            |> Picsello.WHCC.Design.from_map())
        )
      end)
      |> Mox.stub(:design_details, fn %{id: id} = design ->
        Picsello.WHCC.Design.add_details(
          design,
          "designs"
          |> Path.join(id)
          |> read_fixture()
          |> put_in(["product", "_id"], whcc_product_id())
        )
      end)
      |> Mox.stub(:products, fn ->
        [
          %Picsello.WHCC.Product{
            category: %Picsello.WHCC.Category{id: "category-id", name: "cards"},
            name: "little cards",
            id: whcc_product_id()
          }
        ]
      end)

      :ok
    end

    test "adds new" do
      Picsello.WHCC.sync()
      all = Picsello.Design |> Repo.all()
      assert 5 = Enum.count(all)

      assert %Picsello.Design{
               whcc_id: "SjhvrFtjMP7FHy6Qa",
               whcc_name: "warm joyful wishes",
               api: %{"occasion" => %{}},
               attribute_categories: [%{} | _]
             } = hd(all)
    end

    test "updates included existing" do
      %{id: design_id} =
        insert(:design, whcc_id: "SjhvrFtjMP7FHy6Qa", whcc_name: "cold sad wishes")

      Picsello.WHCC.sync()

      assert %Picsello.Design{
               whcc_id: "SjhvrFtjMP7FHy6Qa",
               whcc_name: "warm joyful wishes"
             } = Picsello.Design |> Repo.get(design_id)
    end

    test "removes omitted existing" do
      %{id: design_id} = insert(:design)

      Picsello.WHCC.sync()

      assert [
               [
                 %Picsello.Design{id: ^design_id, deleted_at: %DateTime{}}
               ],
               [_ | _]
             ] =
               Picsello.Design
               |> Repo.all()
               |> Enum.group_by(& &1.deleted_at)
               |> Map.values()
               |> Enum.sort_by(&Enum.count/1)
    end
  end

  describe "sync() - products" do
    setup do
      Picsello.MockWHCCClient
      |> Mox.stub(:products, fn ->
        [
          %Picsello.WHCC.Product{
            id: "product-id",
            name: "jeans",
            api: %{"other" => "keys"},
            attribute_categories: [%{"id" => "size", "name" => "size", "attributes" => []}],
            category: %Picsello.WHCC.Category{id: "category-id", name: "pants"}
          }
        ]
      end)
      |> Mox.stub(:product_details, & &1)

      :ok
    end

    test "adds new products" do
      Picsello.WHCC.sync()

      assert [
               %Picsello.Product{
                 whcc_id: "product-id",
                 whcc_name: "jeans",
                 api: %{"other" => "keys"},
                 attribute_categories: [%{"id" => "size", "name" => "size", "attributes" => []}],
                 category: %Picsello.Category{whcc_id: "category-id", whcc_name: "pants"}
               }
             ] = Picsello.Product |> Repo.all() |> Repo.preload(:category)
    end

    test "updates existing products" do
      insert(:product,
        whcc_id: "product-id",
        whcc_name: "blue jeans",
        attribute_categories: [%{id: "flavor", name: "flavor", attributes: []}]
      )

      Picsello.WHCC.sync()

      assert [
               %Picsello.Product{
                 whcc_id: "product-id",
                 whcc_name: "jeans",
                 attribute_categories: [%{"id" => "size", "name" => "size", "attributes" => []}]
               }
             ] = Repo.all(Picsello.Product)
    end

    test "removes existing products" do
      insert(:product, whcc_id: "socks-id", whcc_name: "socks")

      Picsello.WHCC.sync()

      assert [
               %Picsello.Product{whcc_id: "product-id", whcc_name: "jeans", deleted_at: nil},
               %Picsello.Product{
                 whcc_id: "socks-id",
                 whcc_name: "socks",
                 deleted_at: %DateTime{}
               }
             ] = Repo.all(from(Picsello.Product, order_by: :whcc_name))
    end
  end

  describe "categories" do
    test "hides hiddens and deleteds and sorts by position" do
      insert(:category, hidden: false, deleted_at: DateTime.utc_now(), position: 4)
      insert(:category, hidden: true, position: 3)
      category_two = insert(:category, hidden: false, position: 2)
      category_one = insert(:category, hidden: false, position: 1)

      assert [^category_one, ^category_two] = Picsello.WHCC.categories()
    end
  end

  describe "preload_products" do
    setup do
      whcc_category_id = "tfhysKwZafFtmGqpQ"

      Picsello.MockWHCCClient
      |> Mox.stub(:products, fn ->
        for(
          %{"category" => %{"id" => ^whcc_category_id}} = product <- read_fixture("products"),
          do: Picsello.WHCC.Product.from_map(product)
        )
      end)
      |> Mox.stub(:product_details, fn %{id: id} = product ->
        Picsello.WHCC.Product.add_details(product, read_fixture("products/#{id}"))
      end)
      |> Mox.stub(:designs, fn -> [] end)

      Picsello.WHCC.sync()

      products = Picsello.Product |> Repo.all()

      [products: products, user: insert(:user)]
    end

    test "loads product variations", %{products: products, user: user} do
      [%{variations: variations} | _] =
        products |> Enum.map(& &1.id) |> Picsello.WHCC.preload_products(user) |> Map.values()

      assert %{
               attributes: [
                 %{
                   category_id: "size",
                   category_name: "size",
                   id: "5x5",
                   markup: 100,
                   name: "5×5",
                   price: %Money{amount: 2050, currency: :USD}
                 }
               ],
               id: "size",
               name: "size"
             } = hd(variations)
    end

    test "loads markups", %{products: products, user: user} do
      [product | _] = products

      insert(:markup,
        organization: user.organization,
        whcc_attribute_category_id: "size",
        whcc_attribute_id: "5x5",
        whcc_variation_id: "size",
        product: product,
        value: 2.0
      )

      assert %{markup: 2} =
               products
               |> Enum.map(& &1.id)
               |> Picsello.WHCC.preload_products(user)
               |> Map.values()
               |> Enum.find_value(fn %{variations: variations} ->
                 variations
                 |> Enum.find(&(&1.id == "size"))
                 |> Map.get(:attributes)
                 |> Enum.find_value(fn attribute ->
                   match?(
                     %{
                       category_id: "size",
                       id: "5x5"
                     },
                     attribute
                   ) && attribute
                 end)
               end)
    end
  end
end
