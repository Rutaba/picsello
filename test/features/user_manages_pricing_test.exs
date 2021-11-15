defmodule Picsello.UserManagesPricingTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.{Repo, Package, JobType}

  setup :onboarded
  setup :authenticated

  setup do
    Mox.stub_with(Picsello.MockWHCCClient, Picsello.WHCC.Client)

    Agent.update(Picsello.WHCC.Client.TokenStore, fn _ ->
      %{
        token: "abc",
        expires_at: DateTime.utc_now() |> DateTime.add(1000, :second)
      }
    end)

    Tesla.Mock.mock(fn
      %{method: :get, url: url} ->
        %Tesla.Env{
          status: 200,
          body: "test/support/fixtures/#{url}.json" |> File.read!() |> Jason.decode!()
        }
    end)

    Picsello.WHCC.sync()
    Picsello.Category |> Repo.update_all(set: [hidden: false])

    :ok
  end

  feature "navigate", %{session: session} do
    session
    |> click(link("Settings"))
    |> click(link("Gallery Store Pricing"))
    |> click(link("Loose Prints"))
    |> assert_text("Adjust Pricing: Loose Prints")
    |> click(button("Expand All", at: 0, count: 3))
    |> find(testid("product", at: 0, count: 2))
    |> find(css(".contents", at: 0, count: 32))
    |> click(button("Expand"))
    |> assert_text("$0.94")
  end
end
