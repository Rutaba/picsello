defmodule PicselloWeb.Helpers do
  @moduledoc "This module is used to define functions that can be accessed outside *Web"
  alias PicselloWeb.Endpoint
  alias PicselloWeb.Router.Helpers, as: Routes
  alias Picsello.Cart.Order

  def jobs_url(), do: Routes.job_url(Endpoint, :jobs)
  def job_url(id), do: Routes.job_url(Endpoint, :jobs, id)
  def lead_url(id), do: Routes.job_url(Endpoint, :leads, id)
  def inbox_thread_url(id), do: Routes.inbox_url(Endpoint, :show, id)

  def gallery_url(%{client_link_hash: hash, password: password}),
    do: Routes.gallery_client_show_url(Endpoint, :show, hash, pw: password)

  def download_url(%{client_link_hash: hash}, order),
    do: Routes.gallery_downloads_url(Endpoint, :download, hash, Order.number(order))

  def order_url(%{client_link_hash: hash, password: password}, order),
    do: Routes.gallery_client_order_url(Endpoint, :show, hash, Order.number(order), pw: password)

  defdelegate strftime(zone, date, format), to: PicselloWeb.LiveHelpers

  defdelegate dyn_gettext(key), to: PicselloWeb.Gettext
end
