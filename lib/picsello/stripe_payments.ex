defmodule Picsello.StripePayments do
  @moduledoc false

  @behaviour Picsello.Payments

  alias Picsello.{Repo, Organization, Accounts.User}

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
end
