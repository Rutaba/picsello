defmodule PicselloWeb.GalleryLive.PhotographerOrders do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  alias Picsello.Galleries
  alias Picsello.Cart.Order
  alias Picsello.Repo

  def mount(%{"id" => id}, _, socket) do
    #r = Repo.all()
    r = Repo.get_by(Order, gallery_id: id)
    IO.inspect ["###", r]

    socket |> ok
  end

  def render(assigns) do
    ~H"""
    YO!
    """
  end
end
