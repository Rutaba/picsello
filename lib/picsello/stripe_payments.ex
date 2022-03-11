defmodule Picsello.StripePayments do
  @moduledoc false

  alias Picsello.{Repo, Payments, Organization, Accounts.User}

  @behaviour Payments

  @impl Payments
  def login_link(%User{} = user, opts) do
    %{organization: organization} = user |> Repo.preload(:organization)
    login_link(organization, opts)
  end

  def login_link(%Organization{stripe_account_id: account_id}, opts) do
    redirect_url = opts |> Keyword.get(:redirect_url)

    case Stripe.LoginLink.create(
           account_id,
           %{redirect_url: redirect_url}
         ) do
      {:ok, %{url: url}} -> {:ok, url}
      error -> error
    end
  end

  @impl Payments
  def checkout_link(params, opts) do
    stripe_params =
      Enum.into(params, %{
        payment_method_types: ["card"],
        mode: "payment"
      })

    case Stripe.Session.create(stripe_params, opts) do
      {:ok, %{url: url}} -> {:ok, url}
      error -> error
    end
  end

  @impl Payments
  def retrieve_account(account_id), do: Stripe.Account.retrieve(account_id, [])

  @impl Payments
  defdelegate create_customer(params, opts), to: Stripe.Customer, as: :create

  @impl Payments
  defdelegate retrieve_session(id, opts), to: Stripe.Session, as: :retrieve

  @impl Payments
  defdelegate construct_event(body, stripe_signature, signing_secret), to: Stripe.Webhook

  @impl Payments
  defdelegate create_account_link(params, opts), to: Stripe.AccountLink, as: :create
end
