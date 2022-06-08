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
    Repo
  }

  import Ecto.Query, only: [from: 2, preload: 2]

  def all(gallery_id) do
    photo_query = from(photo in Photo, select: %{photo | watermarked: false})

    from(order in orders(),
      where: order.gallery_id == ^gallery_id,
      preload: [:package, digitals: [photo: ^photo_query], products: :whcc_product],
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

  def paid?(%{id: order_id}),
    do:
      from(order in orders(),
        as: :order,
        where:
          not exists(
            from intents in Intents.unpaid_query(),
              where: intents.order_id == parent_as(:order).id
          ) and
            order.id == ^order_id
      )
      |> Repo.exists?()

  def client_paid?(%{id: order_id}),
    do: Repo.exists?(from orders in client_paid_query(), where: orders.id == ^order_id)

  def client_paid_query, do: client_paid_query(orders())

  def client_paid_query(source),
    do:
      from(orders in source,
        left_join: intents in subquery(Intents.unpaid_query()),
        on: intents.order_id == orders.id,
        where: is_nil(intents.id)
      )

  def orders(), do: from(orders in Order, where: not is_nil(orders.placed_at))

  def get!(gallery, order_number) do
    watermarked_query = Picsello.Photos.watermarked_query()

    gallery
    |> placed_order_query(order_number)
    |> preload(
      gallery: :organization,
      products: :whcc_product,
      digitals: [photo: ^watermarked_query]
    )
    |> Repo.one!()
  end

  @spec get_purchased_photos!(String.t(), %{client_link_hash: String.t()}) ::
          %{organization: %Picsello.Organization{}, photos: [%Photo{}]}
  def get_purchased_photos!(order_number, %{client_link_hash: gallery_hash} = gallery) do
    order = gallery |> placed_order_query(order_number) |> client_paid_query() |> Repo.one!()

    %{
      organization: get_organization!(gallery_hash),
      photos: get_order_photos!(order)
    }
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
        photos: from(photo in Photo, where: photo.gallery_id == ^gallery.id) |> some!()
      }
    else
      raise Ecto.NoResultsError, queryable: Gallery
    end
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

  defp get_order_photos!(%Order{bundle_price: %Money{}} = order) do
    from(photo in Photo, where: photo.gallery_id == ^order.gallery_id)
    |> some!()
  end

  defp get_order_photos!(%Order{id: order_id}) do
    from(order in Order,
      join: digital in assoc(order, :digitals),
      join: photo in assoc(digital, :photo),
      where: order.id == ^order_id,
      select: photo
    )
    |> some!()
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
end
