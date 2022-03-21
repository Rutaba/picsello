defmodule Picsello.ConfigureStripeTest do
  use Picsello.FeatureCase, async: true

  setup :onboarded
  setup :authenticated

  setup %{session: session} do
    fake_stripe_config_url =
      session
      |> current_url()
      |> URI.parse()
      |> Map.merge(%{path: "/home", query: "stripe.me"})
      |> URI.to_string()

    Picsello.MockPayments
    |> Mox.stub(:create_account_link, fn _, _ ->
      {:ok, %{url: fake_stripe_config_url, id: "account-id"}}
    end)
    |> Mox.stub(:retrieve_account, fn _ -> {:ok, %Stripe.Account{}} end)

    :ok
  end

  feature "user configures stripe from lead page overview card", %{session: session, user: user} do
    lead = insert(:lead, %{package: %{}, user: user})

    session
    |> visit("/leads/#{lead.id}")
    |> find(testid("overview-Finances"), &click(&1, button("Set up Stripe")))
    |> assert_url_contains("stripe.me")
  end

  feature "user configures stripe from lead page booking summary", %{session: session, user: user} do
    lead = insert(:lead, %{package: %{}, user: user})

    session
    |> visit("/leads/#{lead.id}")
    |> find(testid("booking-summary"), &click(&1, button("Set up Stripe")))
    |> assert_url_contains("stripe.me")
  end
end
