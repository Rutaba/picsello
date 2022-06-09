defmodule Picsello.Notifiers.OrderNotifier do
  @moduledoc "formats checkout and confirm data into appropriate emails"

  def deliver_order_emails(order, helpers) do
    order =
      Picsello.Repo.preload(order, [
        :products,
        :digitals,
        :invoice,
        :intent,
        gallery: [job: [:package, client: [organization: :user]]]
      ])

    Picsello.Notifiers.ClientNotifier.deliver_order_confirmation(order, helpers)
    Picsello.Notifiers.UserNotifier.deliver_order_confirmation(order, helpers)
  end
end
