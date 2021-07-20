defmodule Picsello.ConfigureStripeTest do
  use Picsello.FeatureCase, async: true

  setup :authenticated

  feature "user configures stripe from job page", %{session: session, user: user} do
    job = insert(:job, %{package: %{}, user: user})

    session
    |> visit("/jobs/#{job.id}")
    |> click(button("Create Stripe Account"))
    |> assert_url_contains("stripe.me")
  end
end
