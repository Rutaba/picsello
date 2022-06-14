defmodule Picsello.Notifiers.OrderNotifier do
  @moduledoc "formats checkout and confirm data into appropriate emails"

  def deliver_order_emails(order, helpers) do
    Picsello.Notifiers.ClientNotifier.deliver_order_confirmation(order, helpers)
  end
end
