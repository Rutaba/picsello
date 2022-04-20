defmodule Picsello.UserFinancesTest do
  use Picsello.FeatureCase, async: true
  require Ecto.Query
  alias Picsello.{Organization, Repo}

  setup :onboarded
  setup :authenticated

  feature "user cannot edit tax info when stripe is not configured", %{session: session} do
    session
    |> click(link("Settings"))
    |> click(link("Finances"))
    |> assert_disabled(button("View tax settings in Stripe"))
    |> assert_text("Set up Stripe to view tax settings")
    |> assert_has(button("Set up Stripe"))
  end

  feature "user can edit tax info when stripe is enabled", %{session: session, user: user} do
    Mox.expect(Picsello.MockPayments, :retrieve_account, fn _, _ ->
      {:ok, %Stripe.Account{charges_enabled: true}}
    end)

    user.organization
    |> Organization.assign_stripe_account_changeset("stripe_id")
    |> Repo.update!()

    session
    |> click(link("Settings"))
    |> click(link("Finances"))
    |> assert_has(
      css("a[href='https://dashboard.stripe.com/settings/tax']",
        text: "View tax settings in Stripe"
      )
    )
    |> assert_has(
      css("a[href='https://dashboard.stripe.com/']",
        text: "Go to Stripe account"
      )
    )
  end
end
