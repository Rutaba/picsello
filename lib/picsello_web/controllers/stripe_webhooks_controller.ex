defmodule PicselloWeb.StripeWebhooksController do
  use PicselloWeb, :controller
  require Logger
  alias Picsello.{Orders, PaymentSchedules, Notifiers.OrderNotifier}

  def connect_webhooks(conn, _params), do: do_webhook(:connect, conn)
  def app_webhooks(conn, _params), do: do_webhook(:app, conn)

  defp do_webhook(event_type, %Plug.Conn{assigns: %{stripe_event: stripe_event}} = conn) do
    case handle_webhook(event_type, stripe_event) do
      {:ok, _} ->
        Logger.info("handled #{event_type} #{stripe_event.type}")

      err ->
        Logger.error("""
        Error handling #{event_type} event.

        Event: #{inspect(stripe_event)}

        Error: #{inspect(err)}
        """)
    end

    Logger.info("handled webhook")
  catch
    kind, value ->
      message = "unhandled error in webhook: #{inspect(kind)}:\n#{inspect(value)}"
      Sentry.capture_message(message, stacktrace: __STACKTRACE__)
      Logger.error(message)
  after
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
  end

  defp handle_webhook(:app, %{type: type, data: %{object: subscription}})
       when type in [
              "customer.subscription.created",
              "customer.subscription.updated",
              "customer.subscription.deleted"
            ] do
    {:ok, _} = Picsello.Subscriptions.handle_stripe_subscription(subscription)
  end

  defp handle_webhook(:app, %{type: type, data: %{object: %Stripe.Invoice{subscription: "" <> _}}})
       when type in [
              "invoice.payment_succeeded",
              "invoice.payment_failed"
            ] do
    Logger.debug("ignored subscription #{type} webhook")
  end

  defp handle_webhook(:app, %{type: type, data: %{object: invoice}})
       when type in [
              "invoice.payment_succeeded",
              "invoice.payment_failed"
            ] do
    {:ok, _} = Orders.handle_invoice(invoice)
  end

  defp handle_webhook(:connect, %{
         type: "checkout.session.completed",
         data: %{object: %{client_reference_id: "order_number_" <> _} = session}
       }),
       do:
         session
         |> Orders.handle_session()
         |> OrderNotifier.deliver_order_confirmation_emails(PicselloWeb.Helpers)

  defp handle_webhook(:connect, %{
         type: "checkout.session.completed",
         data: %{object: %{client_reference_id: "proposal_" <> _} = session}
       }),
       do: PaymentSchedules.handle_payment(session, PicselloWeb.Helpers)

  defp handle_webhook(:connect, %{
         type: "payment_intent.canceled",
         data: %{object: payment_intent}
       }),
       do:
         payment_intent
         |> Orders.handle_intent()
         |> OrderNotifier.deliver_order_cancelation_emails(PicselloWeb.Helpers)

  defp handle_webhook(:app, %{type: type, data: %{object: subscription}})
       when type in [
              "customer.subscription.created",
              "customer.subscription.updated",
              "customer.subscription.deleted"
            ],
       do: Picsello.Subscriptions.handle_stripe_subscription(subscription)

  defp handle_webhook(:app, %{type: type, data: %{object: %Stripe.Invoice{subscription: "" <> _}}})
       when type in [
              "invoice.payment_succeeded",
              "invoice.payment_failed"
            ] do
    {:ok, nil}
  end

  defp handle_webhook(:app, %{type: type, data: %{object: invoice}})
       when type in [
              "invoice.payment_succeeded",
              "invoice.payment_failed"
            ],
       do: Orders.handle_invoice(invoice)
end
