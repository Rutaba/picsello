defmodule Picsello.OrderTransactionsTest do
  use Picsello.FeatureCase, async: true
  import Ecto.Query, only: [from: 2]
  import Money.Sigils
  alias Picsello.{Repo, Cart.Order, Package, Galleries.Photo}

  setup :onboarded
  setup :authenticated

  setup %{user: user, session: session} do
    order =
      insert(:order,
        gallery:
          insert(:gallery,
            job: insert(:lead, user: user) |> promote_to_job()
          ),
        placed_at: DateTime.utc_now(),

      )
    
    [user: user, order: order]
  end

  feature "Transactions table test", %{order: %{gallery: %{job: job}}, session: session} do
    session
    |> visit("/jobs/#{job.id}/transactions")
    Process.sleep(10000000)
  end
end
