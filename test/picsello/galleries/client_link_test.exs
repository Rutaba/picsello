defmodule Picsello.GalleriesTest do
  use Picsello.DataCase

  alias Picsello.Galleries

  @valid_attrs %{name: "MainGallery", status: "active", client_link_hash: nil}

  describe "gallery client link" do
    setup do
      [gallery: insert(:gallery, @valid_attrs)]
    end

    test "creation", %{gallery: gallery} do
      assert gallery.client_link_hash == nil

      linked_gallery = Galleries.set_gallery_hash(gallery)

      assert linked_gallery.client_link_hash != nil
    end

    test "regeneration makes nothing", %{gallery: gallery} do
      linked_gallery = Galleries.set_gallery_hash(gallery)
      assert linked_gallery.client_link_hash != nil

      updated_galery = Galleries.set_gallery_hash(linked_gallery)
      assert linked_gallery.client_link_hash == updated_galery.client_link_hash
    end
  end
end
