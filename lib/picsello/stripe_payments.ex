defmodule Picsello.StripePayments do
  @moduledoc false

  alias Picsello.Payments

  @behaviour Payments

  @impl Payments
  defdelegate create_session(params, opts), to: Stripe.Session, as: :create

  @impl Payments
  defdelegate retrieve_session(id, opts), to: Stripe.Session, as: :retrieve

  @impl Payments
  defdelegate expire_session(id, opts), to: Stripe.Session, as: :expire

  @impl Payments
  defdelegate retrieve_account(account_id, opts), to: Stripe.Account, as: :retrieve

  @impl Payments
  defdelegate create_account(params, opts), to: Stripe.Account, as: :create

  @impl Payments
  def create_billing_portal_session(params), do: Stripe.BillingPortal.Session.create(params)

  @impl Payments
  def retrieve_payment_intent(intent_id, opts),
    do: Stripe.PaymentIntent.retrieve(intent_id, %{}, opts)

  @impl Payments
  def cancel_payment_intent(intent_id, opts),
    do: Stripe.PaymentIntent.cancel(intent_id, %{}, opts)

  @impl Payments
  def capture_payment_intent(intent_id, opts),
    do: Stripe.PaymentIntent.capture(intent_id, %{}, opts)

  @impl Payments
  defdelegate create_customer(params, opts), to: Stripe.Customer, as: :create

  @impl Payments
  defdelegate retrieve_subscription(id, opts), to: Stripe.Subscription, as: :retrieve

  @impl Payments
  defdelegate list_prices(params), to: Stripe.Price, as: :list

  @impl Payments
  defdelegate construct_event(body, stripe_signature, signing_secret), to: Stripe.Webhook

  @impl Payments
  defdelegate create_account_link(params, opts), to: Stripe.AccountLink, as: :create

  @impl Payments
  defdelegate create_invoice(params, opts), to: Stripe.Invoice, as: :create

  @impl Payments
  defdelegate finalize_invoice(id, params, opts), to: Stripe.Invoice, as: :finalize

  @impl Payments
  defdelegate create_invoice_item(params, opts), to: Stripe.Invoiceitem, as: :create

  @impl Payments
  defdelegate void_invoice(id, opts), to: Stripe.Invoice, as: :void
end
