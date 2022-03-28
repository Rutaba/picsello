defmodule Picsello.StripePayments do
  @moduledoc false

  alias Picsello.Payments

  @behaviour Payments

  @impl Payments
  defdelegate create_session(params, opts), to: Stripe.Session, as: :create

  @impl Payments
  defdelegate retrieve_account(account_id, opts), to: Stripe.Account, as: :retrieve

  @impl Payments
  defdelegate create_account(params, opts), to: Stripe.Account, as: :create

  @impl Payments
  defdelegate create_customer(params, opts), to: Stripe.Customer, as: :create

  @impl Payments
  defdelegate retrieve_session(id, opts), to: Stripe.Session, as: :retrieve

  @impl Payments
  defdelegate construct_event(body, stripe_signature, signing_secret), to: Stripe.Webhook

  @impl Payments
  defdelegate create_account_link(params, opts), to: Stripe.AccountLink, as: :create
end
