defmodule Picsello.WHCCTest do
  use Picsello.DataCase

  describe "sync_categories" do
    setup do
      Mox.stub(Picsello.MockWHCCClient, :categories, fn ->
        [%Picsello.WHCC.Category{id: "abc", name: "pants"}]
      end)

      :ok
    end

    test "adds new categories" do
      Picsello.WHCC.sync_categories()

      assert [%Picsello.Category{whcc_id: "abc", whcc_name: "pants"}] =
               Repo.all(Picsello.Category)
    end

    test "updates existing categories" do
      insert(:category, whcc_id: "abc", whcc_name: "socks")

      Picsello.WHCC.sync_categories()

      assert [%Picsello.Category{whcc_id: "abc", whcc_name: "pants"}] =
               Repo.all(Picsello.Category)
    end

    test "removes existing categories" do
      insert(:category, whcc_id: "123", whcc_name: "socks")

      Picsello.WHCC.sync_categories()

      assert [
               %Picsello.Category{whcc_id: "abc", whcc_name: "pants", deleted_at: nil},
               %Picsello.Category{whcc_id: "123", whcc_name: "socks", deleted_at: %DateTime{}}
             ] = Repo.all(from(Picsello.Category, order_by: :whcc_name))
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
end
