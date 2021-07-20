defmodule Picsello.Payments do
  @moduledoc false

  alias Picsello.{Repo, Accounts.User}

  def link(%{stripe_account_id: nil} = user, opts) do
    with {:ok, %{id: account_id}} <- Stripe.Account.create(%{type: "express"}),
         {:ok, user} <-
           user |> User.assign_stripe_account_changeset(account_id) |> Repo.update() do
      link(user, opts)
    else
      {:error, _} = e -> e
      e -> {:error, e}
    end
  end

  def link(%{stripe_account_id: account_id}, opts) do
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

  def status(%User{stripe_account_id: nil}), do: {:ok, nil}

  def status(%User{stripe_account_id: account_id}) do
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
