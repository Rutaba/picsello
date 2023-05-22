defmodule PicselloWeb.GalleryAddAndClone do
  @moduledoc "Handles secondary button in WHCC editor"
  use PicselloWeb, :controller

  alias Picsello.Cart
  alias Picsello.Galleries
  alias Picsello.WHCC

  def post(
        conn,
        %{
          "clone" => "true",
          "hash" => hash,
          "accountId" => in_account_id,
          "editorId" => whcc_editor_id,
          "clientEmail" => client_email
        }
      ) do
    gallery =
      Galleries.get_gallery_by_hash!(hash) |> Picsello.Repo.preload(:gallery_digital_pricing)

    gallery =
      Map.put(
        gallery,
        :credits_available,
        client_email && client_email in gallery.gallery_digital_pricing.email_list
      )

    gallery_account_id = Galleries.account_id(gallery)
    gallery_client = Galleries.get_gallery_client(gallery, client_email)

    if gallery_account_id == in_account_id do
      cart_product = Cart.new_product(whcc_editor_id, gallery.id)
      Cart.place_product(cart_product, gallery, gallery_client)

      url = clone(gallery_account_id, whcc_editor_id)

      conn
      |> json(url)
    else
      conn |> resp(400, "")
    end
  end

  defp clone(gallery_account_id, whcc_editor_id) do
    clone_id = WHCC.editor_clone(gallery_account_id, whcc_editor_id)
    %{url: url} = WHCC.get_existing_editor(gallery_account_id, clone_id)

    url
  end
end
