defmodule PicselloWeb.Helpers do
  @moduledoc "This module is used to define functions that can be accessed outside *Web"
  alias PicselloWeb.Endpoint
  alias PicselloWeb.Router.Helpers, as: Routes
  alias Picsello.Cart.Order
  alias Picsello.Galleries

  def jobs_url(), do: Routes.job_url(Endpoint, :jobs)

  def job_url(id), do: Routes.job_url(Endpoint, :jobs, id)

  def invoice_url(job_id, proposal_id),
    do: Routes.job_download_url(Endpoint, :download_invoice_pdf, job_id, proposal_id)

  def lead_url(id), do: Routes.job_url(Endpoint, :leads, id)

  def inbox_thread_url(id), do: Routes.inbox_url(Endpoint, :show, id)

  def gallery_url("" <> hash),
    do: Routes.gallery_client_index_url(Endpoint, :index, hash)

  def gallery_url(%{client_link_hash: hash}),
    do: Routes.gallery_client_index_url(Endpoint, :index, hash)

  def order_url(%{client_link_hash: hash, password: password}, order),
    do:
      Routes.gallery_client_order_url(Endpoint, :show, hash, Order.number(order),
        pw: password,
        email: Galleries.get_gallery_client_email(order)
      )

  def proofing_album_selections_url(%{client_link_hash: hash, password: password}, order),
    do:
      Routes.gallery_client_order_url(Endpoint, :proofing_album, hash, Order.number(order),
        pw: password,
        email: Galleries.get_gallery_client_email(order)
      )

  def album_url("" <> hash), do: Routes.gallery_client_album_url(Endpoint, :proofing_album, hash)

  def profile_pricing_job_type_url(slug, type),
    do:
      Endpoint
      |> Routes.profile_url(:index, slug)
      |> URI.parse()
      |> Map.put(:fragment, type)
      |> URI.to_string()

  def ngettext(singular, plural, count) do
    Gettext.dngettext(PicselloWeb.Gettext, "picsello", singular, plural, count, %{})
  end

  def days_distance(%DateTime{} = datetime),
    do: datetime |> DateTime.to_date() |> days_distance()

  def days_distance(%Date{} = date), do: date |> Date.diff(Date.utc_today())

  defdelegate strftime(zone, date, format), to: PicselloWeb.LiveHelpers

  defdelegate dyn_gettext(key), to: PicselloWeb.Gettext

  defdelegate shoot_location(shoot), to: PicselloWeb.LiveHelpers
end
