defmodule Picsello.Notifiers.OrderNotifier do
  @moduledoc "formats checkout and confirm data into appropriate emails"

  alias Picsello.Notifiers.{ClientNotifier, UserNotifier}

  def deliver_order_confirmation_emails(
        %Picsello.Cart.Order{placed_at: %DateTime{}} = order,
        helpers
      ) do
    order =
      Picsello.Repo.preload(order, [
        :products,
        :digitals,
        :invoice,
        :intent,
        :album,
        gallery: [job: [:package, client: [organization: :user]]]
      ])

    with {:ok, _client_email} <- ClientNotifier.deliver_order_confirmation(order, helpers) do
      UserNotifier.deliver_order_confirmation(order, helpers)
    end
  end

  def deliver_order_confirmation_emails({:ok, order, :confirmed}, helpers),
    do: deliver_order_confirmation_emails(order, helpers)

  def deliver_order_confirmation_emails({:ok, _order, _status}, _), do: {:ok, nil}
  def deliver_order_confirmation_emails(error, _), do: error

  def deliver_order_cancelation_emails({:ok, %{order: order}}, helpers) do
    with {:ok, _client_email} <- ClientNotifier.deliver_order_cancelation(order, helpers) do
      UserNotifier.deliver_order_cancelation(order, helpers)
    end
  end

  def deliver_order_cancelation_emails(error, _helpers), do: error
end
