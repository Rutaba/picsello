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
    |> Mox.stub(:status, fn _ -> {:ok, :no_account} end)
    |> Mox.stub(:link, fn _, _ -> {:ok, fake_stripe_config_url} end)

    :ok
  end

  feature "user configures stripe from job page", %{session: session, user: user} do
    job = insert(:job, %{package: %{}, user: user})

    session
    |> visit("/leads/#{job.id}")
    |> click(button("Create Stripe Account"))
    |> assert_url_contains("stripe.me")
  end
end
