defmodule Picsello.PackagesTest do
  use Picsello.DataCase, async: true

  alias Picsello.{Repo, Packages, Packages.Download}
  import Money.Sigils

  @default_each_price Download.default_each_price()

  describe "Download.from_package" do
    test "new packages charge 50 ea with no credits" do
      assert %{
               each_price: @default_each_price,
               is_enabled: true,
               is_custom_price: false
             } = Download.from_package(%{download_each_price: nil, download_count: nil})
    end

    test "existing package with default price is same" do
      assert %{
               each_price: @default_each_price,
               is_enabled: true,
               is_custom_price: false
             } = Download.from_package(%{download_each_price: ~M[5000]USD, download_count: nil})
    end

    test "existing package with custom price is_custom_price" do
      assert %{
               each_price: ~M[1000]USD,
               is_enabled: true,
               is_custom_price: true
             } = Download.from_package(%{download_each_price: ~M[1000]USD, download_count: nil})
    end

    test "existing package with zero each_price is disabled" do
      assert %{
               count: nil,
               each_price: ~M[0]USD,
               is_enabled: false,
               is_custom_price: false,
               includes_credits: false
             } = Download.from_package(%{download_each_price: ~M[0]USD, download_count: 0})
    end

    test "existing package with credits includes_credits" do
      assert %{
               count: 12,
               includes_credits: true
             } = Download.from_package(%{download_each_price: ~M[0]USD, download_count: 12})
    end
  end

  describe "Download.changeset" do
    test "if includes_credits count must be positive" do
      assert %{errors: [count: {_, validation: :required}]} =
               Download.changeset(%{includes_credits: true})

      assert %{errors: [count: {_, validation}]} =
               Download.changeset(%{includes_credits: true, count: 0})

      assert :number = Keyword.get(validation, :validation)

      assert %{errors: [count: _]} =
               Download.changeset(%Download{count: 0}, %{includes_credits: true})
    end
  end

  describe "create_initial" do
    test "finds price matching experience, time, and type" do
      organization = insert(:organization, profile: %{job_types: ["wedding", "event"]})

      user =
        insert(:user,
          onboarding: %{schedule: :full_time, state: "OK", photographer_years: 3},
          organization: organization
        )

      csvs =
        for(
          {name, csv} <- %{
            prices: """
            Time Experience Type Tier Price
            Part-Time	0	Other	Low	$100
            Full-Time	0	Other	Low	$200
            Full-Time	0	Other	Mid	$300
            Full-Time	0	Other	High	$400
            Full-Time	1-2	Wedding	Low	$500
            Full-Time	1-2	Wedding	Mid	$600
            Full-Time	1-2	Wedding	High	$700
            Full-Time	1-2	Family	Low	$800
            Full-Time	1-2	Family	Mid	$900
            Full-Time	1-2	Family	High	$1,000
            Full-Time	1-2	Event	Low	$1,100
            Full-Time	1-2	Event	Mid	$1,200
            Full-Time	1-2	Event	High	$1,300
            Full-Time	0	Wedding	Low	$1,4000
            Full-Time	0	Wedding	Mid	$1,5000
            Full-Time	0	Wedding	High	$1,6000
            """,
            cost_of_living: """
            state percent
            IL -8%
            OK -10%
            """
          }
        ) do
          {Application.get_env(:picsello, :packages) |> get_in([:calculator, name]),
           csv |> String.split("\n") |> Enum.map(&String.split/1)}
        end

      Tesla.Mock.mock(fn
        %{method: :get, url: url} ->
          path = url |> URI.parse() |> Map.get(:path) |> URI.decode()

          csvs
          |> Enum.find_value(fn {range, data} ->
            if String.contains?(path, range),
              do: %Tesla.Env{
                status: 200,
                body:
                  Jason.encode!(%{
                    "values" => data,
                    "range" => range,
                    "majorDimension" => "ROWS"
                  })
              }
          end)
      end)

      Picsello.Workers.SyncTiers.perform(nil)

      Packages.create_initial(user)

      %{organization: %{package_templates: templates}} =
        Repo.preload(user, organization: :package_templates)

      assert [
               %{name: "high event", base_price: %Money{amount: 117_000}},
               %{name: "high wedding", base_price: %Money{amount: 63_000}},
               %{name: "low event", base_price: %Money{amount: 99_000}},
               %{name: "low wedding", base_price: %Money{amount: 45_000}},
               %{name: "mid event", base_price: %Money{amount: 108_000}},
               %{name: "mid wedding", base_price: %Money{amount: 54_000}}
             ] = templates |> Enum.sort_by(& &1.name)
    end
  end
end
