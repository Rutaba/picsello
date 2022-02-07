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
            Time	Experience	Type	Tier	Price	Shoots	Downloads Turnaround
            Part-Time	0	Other	Bronze	$100.00	1	5	3
            Full-Time	0	Other	Bronze	$200.00	1	5	3
            Full-Time	0	Other	Silver	$300.00	1	10	3
            Full-Time	0	Other	Gold	$400.00	1	20	3
            Full-Time	1-2	Wedding	Bronze	$500.00	2	5	12
            Full-Time	1-2	Wedding	Silver	$600.00	2	10	12
            Full-Time	1-2	Wedding	Gold	$700.00	2	20	12
            Full-Time	1-2	Family	Bronze	$800.00	1	5	3
            Full-Time	1-2	Family	Silver	$900.00	1	10	3
            Full-Time	1-2	Family	Gold	$1,000.00	1	20	3
            Full-Time	1-2	Event	Bronze	$1,100.00	1	5	3
            Full-Time	1-2	Event	Silver	$1,200.00	1	10	3
            Full-Time	1-2	Event	Gold	$1,300.00	1	20	3
            Full-Time	0	Wedding	Bronze	$1,4000.00	2	5	12
            Full-Time	0	Wedding	Silver	$1,5000.00	2	10	12
            Full-Time	0	Wedding	Gold	$1,6000.00	2	20	12
            """,
            cost_of_living: """
            state percent
            IL	-8%
            OK	-3%
            """
          }
        ) do
          {Application.get_env(:picsello, :packages) |> get_in([:calculator, name]),
           csv |> String.split("\n") |> Enum.map(&String.split(&1, "\t"))}
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
               %{
                 name: "Bronze Event",
                 base_price: %Money{amount: 106_500},
                 download_count: 5,
                 shoot_count: 1,
                 turnaround_weeks: 3
               },
               %{
                 name: "Bronze Wedding",
                 base_price: %Money{amount: 48_500},
                 download_count: 5,
                 shoot_count: 2,
                 turnaround_weeks: 12
               },
               %{
                 name: "Gold Event",
                 base_price: %Money{amount: 126_000},
                 download_count: 20,
                 shoot_count: 1,
                 turnaround_weeks: 3
               },
               %{
                 name: "Gold Wedding",
                 base_price: %Money{amount: 68_000},
                 download_count: 20,
                 shoot_count: 2,
                 turnaround_weeks: 12
               },
               %{
                 name: "Silver Event",
                 base_price: %Money{amount: 116_500},
                 download_count: 10,
                 shoot_count: 1,
                 turnaround_weeks: 3
               },
               %{
                 name: "Silver Wedding",
                 base_price: %Money{amount: 58_000},
                 download_count: 10,
                 shoot_count: 2,
                 turnaround_weeks: 12
               }
             ] = templates |> Enum.sort_by(& &1.name)
    end
  end
end
