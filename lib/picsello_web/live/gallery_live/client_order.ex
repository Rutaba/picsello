defmodule PicselloWeb.GalleryLive.ClientOrder do
  @moduledoc false

  use PicselloWeb, live_view: [layout: "live_client"]
  alias Picsello.Cart
  alias Picsello.Galleries

  def handle_params(
        %{"order_id" => order_id},
        _,
        %{assigns: %{gallery: gallery, live_action: :paid}} = socket
      ) do
    with {:ok, order} <- Cart.get_unconfirmed_order(gallery.id) do
      Cart.confirm_order(order, Galleries.account_id(gallery))
    end

    socket
    |> push_redirect(
      to: Routes.gallery_client_order_path(socket, :show, gallery.client_link_hash, order_id)
    )
    |> noreply()
  end

  def handle_params(_, _, %{assigns: %{live_action: :show}} = socket) do
    socket
    |> noreply()
  end

  def render(assigns) do
    ~H"""
    """
  end
end
