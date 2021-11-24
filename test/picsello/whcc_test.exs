defmodule Picsello.WHCCTest do
  use Picsello.DataCase

  setup do
    Mox.stub(Picsello.MockWHCCClient, :product_details, fn product ->
      %{
        product
        | attribute_categories: [
            %{"id" => "size", "name" => "size", "attributes" => []}
          ]
      }
    end)

    :ok
  end

  describe "sync() - categories" do
    setup do
      Mox.stub(Picsello.MockWHCCClient, :products, fn ->
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

  describe "sync() - products" do
    setup do
      Mox.stub(Picsello.MockWHCCClient, :products, fn ->
        [
          %Picsello.WHCC.Product{
            id: "product-id",
            name: "jeans",
            attribute_categories: [%{id: "flavor", name: "flavor", attributes: []}],
            category: %Picsello.WHCC.Category{id: "category-id", name: "pants"}
          }
        ]
      end)

      :ok
    end

    test "adds new products" do
      Picsello.WHCC.sync()

      assert [
               %Picsello.Product{
                 whcc_id: "product-id",
                 whcc_name: "jeans",
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
      insert(:category, hidden: false, deleted_at: DateTime.utc_now())
      insert(:category, hidden: true)
      category_two = insert(:category, hidden: false, position: 2)
      category_one = insert(:category, hidden: false, position: 1)

      assert [^category_one, ^category_two] = Picsello.WHCC.categories()
    end
  end

  describe "category" do
    test "filters out products without variations" do
      whcc_category_id = "tfhysKwZafFtmGqpQ"

      read_fixture = &("test/support/fixtures/#{&1}.json" |> File.read!() |> Jason.decode!())

      Mox.stub(Picsello.MockWHCCClient, :products, fn ->
        for(
          %{"category" => %{"id" => ^whcc_category_id}} = product <- read_fixture.("products"),
          do: Picsello.WHCC.Product.from_map(product)
        )
      end)

      Mox.stub(Picsello.MockWHCCClient, :product_details, fn %{id: id} = product ->
        %{
          product
          | attribute_categories:
              "products/#{id}" |> read_fixture.() |> Map.get("attributeCategories")
        }
      end)

      Picsello.WHCC.sync()
      id = Picsello.Category |> Repo.get_by(whcc_id: whcc_category_id) |> Map.get(:id)

      Repo.update_all(Picsello.Category, set: [hidden: false])

      %{products: products} = Picsello.WHCC.category(id)

      assert [
               "Bamboo Panel",
               "Standout",
               "Framed Print",
               "Float Frame",
               "Image Block",
               "Metal Print",
               "Acrylic Print"
             ] = products |> Enum.map(& &1.whcc_name)
    end
  end

  describe "variations" do
    test "only returns variations with variations" do
    end
  end
end
