defmodule Picsello.UserManagesPricingTest do
  use Picsello.FeatureCase, async: true
  alias Picsello.Repo

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

    base_path =
      with "" <> url <- :picsello |> Application.get_env(:whcc) |> Keyword.get(:url),
           %{path: "" <> base_path} <- URI.parse(url) do
        base_path
      else
        _ -> ""
      end

    Tesla.Mock.mock(fn
      %{method: :get, url: url} ->
        %{path: path} = URI.parse(url)
        file_path = String.split(path, base_path, parts: 2, trim: true)

        %Tesla.Env{
          status: 200,
          body: "test/support/fixtures/#{file_path}.json" |> File.read!() |> Jason.decode!()
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
