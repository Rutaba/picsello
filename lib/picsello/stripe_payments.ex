defmodule Picsello.StripePayments do
  @moduledoc false

  @behaviour Picsello.Payments

  alias Picsello.{Repo, BookingProposal, Organization, Accounts.User, Client}

  def link(%User{} = user, opts) do
    %{organization: organization} = user |> Repo.preload(:organization)
    link(organization, opts)
  end

  def link(%Organization{stripe_account_id: nil} = organization, opts) do
    with {:ok, %{id: account_id}} <- Stripe.Account.create(%{type: "express"}),
         {:ok, organization} <-
           organization
           |> Organization.assign_stripe_account_changeset(account_id)
           |> Repo.update() do
      link(organization, opts)
    else
      {:error, _} = e -> e
      e -> {:error, e}
    end
  end

  def link(%Organization{stripe_account_id: account_id}, opts) do
    refresh_url = opts |> Keyword.get(:refresh_url)
    return_url = opts |> Keyword.get(:return_url)

    case Stripe.AccountLink.create(%{
           account: account_id,
           refresh_url: refresh_url,
           return_url: return_url,
           type: "account_onboarding"
         }) do
      {:ok, %{url: url}} -> {:ok, url}
      error -> error
    end
  end

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

  def status(%User{} = user) do
    %{organization: organization} = user |> Repo.preload(:organization)
    status(organization)
  end

  def status(%Organization{stripe_account_id: nil}), do: {:ok, :none}

  def status(%Organization{stripe_account_id: account_id}) do
    case Stripe.Account.retrieve(account_id) do
      {:ok, account} ->
        {:ok,
         [:charges_enabled, :details_submitted]
         |> Enum.find(:processing, &Map.get(account, &1))}

      e ->
        e
    end
  end

  def customer_id(%Client{stripe_customer_id: nil} = client) do
    params = %{name: client.name, email: client.email}
    %{organization: organization} = client |> Repo.preload(:organization)

    with {:ok, %{id: customer_id}} <-
           Stripe.Customer.create(params, connect_account: organization.stripe_account_id),
         {:ok, client} <-
           client
           |> Client.assign_stripe_customer_changeset(customer_id)
           |> Repo.update() do
      client.stripe_customer_id
    else
      {:error, _} = e -> e
      e -> {:error, e}
    end
  end

  def customer_id(%Client{stripe_customer_id: customer_id}), do: customer_id

  def checkout_link(%BookingProposal{} = proposal, line_items, opts) do
    cancel_url = opts |> Keyword.get(:cancel_url)
    success_url = opts |> Keyword.get(:success_url)

    %{job: %{client: client, organization: organization}} =
      proposal |> Repo.preload(job: [:organization, :client])

    customer_id = customer_id(client)

    stripe_params = %{
      client_reference_id: "proposal_#{proposal.id}",
      cancel_url: cancel_url,
      success_url: success_url,
      payment_method_types: ["card"],
      customer: customer_id,
      mode: "payment",
      line_items: line_items
    }

    case Stripe.Session.create(stripe_params, connect_account: organization.stripe_account_id) do
      {:ok, %{url: url}} -> {:ok, url}
      error -> error
    end
  end

  defdelegate construct_event(body, stripe_signature, signing_secret), to: Stripe.Webhook
end
