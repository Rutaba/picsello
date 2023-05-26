defmodule Picsello.GalleriesTest do
  use Picsello.DataCase

  alias Picsello.Galleries
  alias Picsello.Galleries.{Gallery, Watermark}
  alias Picsello.Repo
  alias Picsello.Job

  @valid_attrs %{name: "MainGallery", status: :active}
  @update_attrs %{status: :expired}
  @invalid_attrs %{status: :draft}

  def gallery_fixture(attrs \\ %{}) do
    insert(:gallery, attrs)
  end

  describe "galleries" do
    test "get_gallery!/1 returns the gallery with given id" do
      gallery = gallery_fixture(@valid_attrs)
      %{id: gallery_id} = Galleries.get_gallery!(gallery.id)

      assert gallery_id == gallery.id
    end

    test "create_gallery/1 with valid data creates a gallery" do
      user = insert(:user, name: "Jane Doe")
      %{id: job_id} = insert(:lead)

      assert {:ok, %Gallery{}} =
               Galleries.create_gallery(user, Map.put(@valid_attrs, :job_id, job_id))
    end

    test "create_gallery/1 with valid data creates a gallery with gallery products" do
      user = insert(:user, name: "Jane Doe")
      %{id: job_id} = insert(:lead)
      insert(:category, deleted_at: DateTime.utc_now())
      insert(:category, hidden: true)
      %{id: active_category_id} = insert(:category)

      assert {:ok, %Gallery{} = gallery} =
               Galleries.create_gallery(user, Map.put(@valid_attrs, :job_id, job_id))

      assert %Gallery{
               gallery_products: [%Galleries.GalleryProduct{category_id: ^active_category_id}]
             } = Repo.preload(gallery, :gallery_products)
    end

    test "create_gallery/1 with invalid data returns error changeset" do
      user = insert(:user, name: "Jane Doe")
      %{id: job_id} = insert(:lead)

      assert {:error, %Ecto.Changeset{}} =
               Galleries.create_gallery(user, Map.put(@invalid_attrs, :job_id, job_id))
    end

    test "update_gallery/2 with valid data updates the gallery" do
      gallery = gallery_fixture(@valid_attrs)
      assert {:ok, %Gallery{}} = Galleries.update_gallery(gallery, @update_attrs)
    end

    test "update_gallery/2 with invalid data returns error changeset" do
      gallery = gallery_fixture(@valid_attrs)

      assert {:error, %Ecto.Changeset{}} =
               Galleries.update_gallery(gallery, Map.put(@invalid_attrs, :job_id, gallery.job_id))
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

    test "resets gallery name" do
      gallery = gallery_fixture(@valid_attrs)
      gallery = Galleries.reset_gallery_name(gallery)
      %{job: job} = gallery |> Repo.preload(:job)

      assert gallery.name == Job.name(job)
    end

    test "regenerates gallery password" do
      gallery = gallery_fixture(@valid_attrs)
      %{password: password} = Galleries.regenerate_gallery_password(gallery)

      assert gallery.password != password
    end
  end

  describe "gallery watermarks" do
    setup do
      [gallery: insert(:gallery, @valid_attrs)]
    end

    test "creates watermark", %{gallery: gallery} do
      watermark_change = Galleries.gallery_text_watermark_change(nil, %{text: "007 Agency"})
      {:ok, %{watermark: watermark}} = Galleries.save_gallery_watermark(gallery, watermark_change)

      assert %Watermark{} = watermark
      assert watermark.gallery_id == gallery.id
    end

    test "updates watermark", %{gallery: gallery} do
      text_watermark_change = Galleries.gallery_text_watermark_change(nil, %{text: "007 Agency"})

      {:ok, %{watermark: text_watermark}} =
        Galleries.save_gallery_watermark(gallery, text_watermark_change)

      image_watermark_change =
        Galleries.gallery_image_watermark_change(text_watermark, %{name: "hex.png", size: 12_345})

      {:ok, %{watermark: image_watermark}} =
        Galleries.save_gallery_watermark(gallery, image_watermark_change)

      assert text_watermark.id == image_watermark.id
    end

    test "preloads watermark", %{gallery: gallery} do
      watermark_change = Galleries.gallery_text_watermark_change(nil, %{text: "007 Agency"})
      {:ok, %{watermark: watermark}} = Galleries.save_gallery_watermark(gallery, watermark_change)
      gallery = Galleries.load_watermark_in_gallery(gallery)

      assert watermark == gallery.watermark
    end

    test "deletes watermark", %{gallery: gallery} do
      watermark_change = Galleries.gallery_text_watermark_change(nil, %{text: "007 Agency"})
      {:ok, %{watermark: watermark}} = Galleries.save_gallery_watermark(gallery, watermark_change)

      Galleries.delete_gallery_watermark(watermark)
      gallery = Galleries.load_watermark_in_gallery(gallery)

      assert nil == gallery.watermark
    end
  end
end
