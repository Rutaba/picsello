defmodule Picsello.GalleriesTest do
  use Picsello.DataCase

  alias Picsello.Galleries

  describe "galleries" do
    alias Picsello.Galleries.Gallery


    @valid_attrs %{name: "MainGallery", status: "active"}
    @update_attrs %{status: "expired"}
    @invalid_attrs %{status: "inactive"}

    def gallery_fixture(attrs \\ %{}) do
      insert(:gallery, attrs)
    end

    test "list_galleries/0 returns all galleries" do
      gallery = gallery_fixture(@valid_attrs)
      assert Galleries.list_galleries() == [gallery]
    end

    test "get_gallery!/1 returns the gallery with given id" do
      gallery = gallery_fixture(@valid_attrs)
      assert Galleries.get_gallery!(gallery.id) == gallery
    end

    test "create_gallery/1 with valid data creates a gallery" do
      %{id: job_id} = insert(:lead)
      assert {:ok, %Gallery{}} = Galleries.create_gallery(Map.put(@valid_attrs, :job_id, job_id))
    end

    test "create_gallery/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Galleries.create_gallery(@invalid_attrs)
    end

    test "update_gallery/2 with valid data updates the gallery" do
      gallery = gallery_fixture(@valid_attrs)
      assert {:ok, %Gallery{}} = Galleries.update_gallery(gallery, @update_attrs)
    end

    test "update_gallery/2 with invalid data returns error changeset" do
      gallery = gallery_fixture(@valid_attrs)
      assert {:error, %Ecto.Changeset{}} = Galleries.update_gallery(gallery, @invalid_attrs)
      assert gallery == Galleries.get_gallery!(gallery.id)
    end

    test "delete_gallery/1 deletes the gallery" do
      gallery = gallery_fixture(@valid_attrs)
      assert {:ok, %Gallery{}} = Galleries.delete_gallery(gallery)
      assert_raise Ecto.NoResultsError, fn -> Galleries.get_gallery!(gallery.id) end
    end

    test "change_gallery/1 returns a gallery changeset" do
      gallery = gallery_fixture(@valid_attrs)
      assert %Ecto.Changeset{} = Galleries.change_gallery(gallery)
    end
  end
end
