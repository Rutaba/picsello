defmodule Picsello.Orders do
  @moduledoc "context module for working with checked out carts"
  alias Picsello.{
    Cart.Digital,
    Cart.Order,
    Cart.OrderNumber,
    Galleries,
    Galleries.Gallery,
    Galleries.Photo,
    Intents,
    Invoices.Invoice,
    Photos,
    Repo
  }

  import Ecto.Query, only: [from: 2, preload: 2]

  def all(gallery_id) do
    photo_query = from(photo in Photo, select: %{photo | watermarked: false})

    from(order in orders(),
      where: order.gallery_id == ^gallery_id,
      preload: [
        :package,
        :intent,
        :canceled_intents,
        digitals: [photo: ^photo_query],
        products: :whcc_product
      ],
      order_by: [desc: order.placed_at]
    )
    |> Repo.all()
  end

  defp topic(order), do: "order:#{Order.number(order)}"

  def subscribe(order), do: Phoenix.PubSub.subscribe(Picsello.PubSub, topic(order))

  def broadcast(order, message),
    do: Phoenix.PubSub.broadcast(Picsello.PubSub, topic(order), message)

  def has_download?(%Order{bundle_price: bundle_price, digitals: digitals}),
    do: bundle_price != nil || digitals != []

  def client_paid?(%{id: order_id}),
    do: Repo.exists?(from orders in client_paid_query(), where: orders.id == ^order_id)

  def photographer_paid?(%{id: order_id}),
    do:
      not Repo.exists?(
        from invoice in Invoice, where: invoice.order_id == ^order_id and invoice.status != :paid
      )

  def client_paid_query, do: client_paid_query(orders())

  def client_paid_query(source),
    do:
      from(orders in source,
        left_join: intents in subquery(Intents.unpaid_query()),
        on: intents.order_id == orders.id,
        where: is_nil(intents.id)
      )

  def orders(), do: from(orders in Order, where: not is_nil(orders.placed_at))

  def placed_orders_count(nil), do: 0

  def placed_orders_count(gallery),
    do:
      from(o in Order,
        select: count(o.id),
        where: o.gallery_id == ^gallery.id and not is_nil(o.placed_at)
      )
      |> Repo.one()

  def get!(gallery, order_number) do
    watermarked_query = Picsello.Photos.watermarked_query()

    gallery
    |> placed_order_query(order_number)
    |> preload([
      :intent,
      :canceled_intents,
      [
        :album,
        gallery: [:organization, :package],
        products: :whcc_product,
        digitals: [photo: ^watermarked_query]
      ]
    ])
    |> Repo.one!()
  end

  def get_purchased_photo!(gallery, photo_id) do
    if can_download_all?(gallery) do
      from(photo in Photo, where: photo.gallery_id == ^gallery.id and photo.id == ^photo_id)
      |> Repo.one!()
    else
      from(digital in Digital,
        join: order in subquery(client_paid_query()),
        on: order.id == digital.order_id,
        join: photo in assoc(digital, :photo),
        where: order.gallery_id == ^gallery.id and digital.photo_id == ^photo_id,
        select: photo
      )
      |> Repo.one!()
    end
  end

  def get_all_photos!(%{client_link_hash: gallery_hash} = gallery) do
    if can_download_all?(gallery) do
      %{
        organization: get_organization!(gallery_hash),
        photos:
          from(photo in Photos.active_photos(), where: photo.gallery_id == ^gallery.id) |> some!()
      }
    else
      raise Ecto.NoResultsError, queryable: Gallery
    end
  end

  def get_all_photos(gallery) do
    {:ok, get_all_photos!(gallery)}
  rescue
    e in Ecto.NoResultsError -> {:error, e}
  end

  @doc "stores processing info in order it finds"
  def update_whcc_order(%{entry_id: entry_id} = payload, helpers) do
    case from(order in Order,
           where: fragment("? ->> 'entry_id' = ?", order.whcc_order, ^entry_id),
           preload: [products: :whcc_product]
         )
         |> Repo.one() do
      nil ->
        {:error, "order not found"}

      order ->
        order
        |> Order.whcc_order_changeset(payload)
        |> Repo.update()
        |> case do
          {:ok, updated_order} ->
            maybe_send_shipping_notification(payload, updated_order, helpers)
            {:ok, updated_order}

          error ->
            error
        end
    end
  end

  defp maybe_send_shipping_notification(
         %Picsello.WHCC.Webhooks.Event{event: "Shipped"} = event,
         order,
         helpers
       ) do
    Picsello.Notifiers.ClientNotifier.deliver_shipping_notification(event, order, helpers)
    Picsello.Notifiers.UserNotifier.deliver_shipping_notification(event, order, helpers)
  end

  defp maybe_send_shipping_notification(_payload, _order, _helpers), do: nil

  def can_download_all?(%Gallery{} = gallery) do
    Galleries.do_not_charge_for_download?(gallery) || bundle_purchased?(gallery)
  end

  def bundle_purchased?(%{id: gallery_id}) do
    from(order in client_paid_query(),
      where: order.gallery_id == ^gallery_id and not is_nil(order.bundle_price)
    )
    |> Repo.exists?()
  end

  defdelegate handle_session(order_number, stripe_session_id),
    to: __MODULE__.Confirmations

  defdelegate handle_session(session), to: __MODULE__.Confirmations
  defdelegate handle_invoice(invoice), to: __MODULE__.Confirmations
  defdelegate handle_intent(intent), to: __MODULE__.Confirmations
  defdelegate canceled?(order), to: Order
  defdelegate number(order), to: Order

  def get_order_photos(%Order{bundle_price: %Money{}} = order) do
    from(photo in Photo,
      where: photo.gallery_id == ^order.gallery_id,
      order_by: [asc: photo.inserted_at]
    )
  end

  def get_order_photos(%Order{id: order_id}) do
    from(order in Order,
      join: digital in assoc(order, :digitals),
      join: photo in assoc(digital, :photo),
      where: order.id == ^order_id,
      order_by: [asc: photo.inserted_at],
      select: photo
    )
  end

  defp some!(query),
    do:
      query
      |> Repo.all()
      |> (case do
            [] -> raise Ecto.NoResultsError, queryable: query
            some -> some
          end)

  defp placed_order_query(%{client_link_hash: gallery_hash}, order_number) do
    order_id = OrderNumber.from_number(order_number)

    from(order in orders(),
      as: :order,
      join: gallery in assoc(order, :gallery),
      as: :gallery,
      where: gallery.client_link_hash == ^gallery_hash and order.id == ^order_id
    )
  end

  defp get_organization!(gallery_hash) do
    from(gallery in Gallery,
      join: org in assoc(gallery, :organization),
      where: gallery.client_link_hash == ^gallery_hash,
      select: org
    )
    |> Repo.one!()
  end

  @filtered_days 7
  def get_all_proofing_album_orders(organization_id) do
    from(order in get_all_proofing_album_orders_query(organization_id),
      where: order.inserted_at > ago(@filtered_days, "day")
    )
  end

  def get_all_proofing_album_orders_query(organization_id) do
    from(order in get_all_orders_query(organization_id),
      join: album in assoc(order, :album),
      where: album.is_proofing == true and not is_nil(order.placed_at),
      preload: [:album, gallery: [job: [:client]]]
    )
  end

  def has_proofing_album_orders?(gallery) do
    Repo.exists?(
      from(order in get_all_proofing_album_orders_query(gallery.organization.id),
        where: order.gallery_id == ^gallery.id and order.inserted_at > ago(7, "day")
      )
    )
  end

  def get_all_orders_query(organization_id) do
    from(order in Picsello.Cart.Order,
      join: gallery in assoc(order, :gallery),
      join: job in assoc(gallery, :job),
      join: client in assoc(job, :client),
      join: organization in assoc(client, :organization),
      where: organization.id == ^organization_id
    )
  end

  @filtered_days 7
  def get_all_proofing_album_orders(organization_id) do
    from(order in get_all_proofing_album_orders_query(organization_id),
      where: order.inserted_at > ago(@filtered_days, "day")
    )
    |> Repo.all()
  end

  def has_proofing_album_orders?(gallery) do
    Repo.exists?(
      from(order in get_all_proofing_album_orders_query(gallery.organization.id),
        where: order.gallery_id == ^gallery.id
      )
    )
  end

  def get_proofing_order(album_id, organization_id) do
    from(order in get_all_proofing_album_orders_query(organization_id),
      where: order.album_id == ^album_id,
      preload: [gallery: [job: [:client]]]
    )
    |> Repo.all()
  end

  def get_proofing_order_photos(album_id, organization_id) do
    photo_query = from(photo in Photo, select: %{photo | watermarked: false})

    from(order in get_all_proofing_album_orders_query(organization_id),
      where: order.album_id == ^album_id,
      preload: [
        digitals: [photo: ^photo_query]
      ],
      order_by: [desc: order.placed_at]
    )
    |> Repo.all()
  end
end
