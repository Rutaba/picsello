defmodule Picsello.PackagesTest do
  use Picsello.DataCase, async: true

  alias Picsello.{Repo, Packages, Packages.Download, OrganizationJobType}

  describe "Download.changeset" do
    test "if includes_credits count must be positive" do
      assert %{errors: [count: {_, validation: :required}]} =
               Download.changeset(%{"includes_credits" => true, "status" => :limited, "step" => :pricing})

      assert %{errors: [count: {_, validation}]} =
               Download.changeset(%{"includes_credits" => true, "count" => 0, "status" => :limited, "step" => :pricing})

      assert :number = Keyword.get(validation, :validation)

      assert %{errors: [count: _]} =
               Download.changeset(%Download{count: 0}, %{"includes_credits" => true, "status" => :limited, "step" => :pricing})
    end
  end

  describe "create_initial" do
    test "finds price matching experience, time, and type" do
      organization = insert(:organization)

      organization
      |> Repo.preload(:organization_job_types)
      |> Ecto.Changeset.change(
        organization_job_types: [
          %OrganizationJobType{
            job_type: "event",
            show_on_business?: true,
            show_on_profile?: true
          },
          %OrganizationJobType{
            job_type: "wedding",
            show_on_business?: true,
            show_on_profile?: true
          }
        ]
      )
      |> Repo.update!()

      user =
        insert(:user,
          onboarding: %{schedule: :full_time, state: "OK", photographer_years: 3},
          organization: organization
        )

      csvs =
        for(
          {name, tsv} <- %{
            prices:
              """
              Time	Experience	Type	Tier	Price	Shoots	Downloads	Turnaround	Max
              Part-Time	0	Other	Essential	$100.00	1	5	3	3
              Full-Time	0	Other	Essential	$200.00	1	5	3	3
              Full-Time	0	Other	Keepsake	$300.00	1	10	3	3
              Full-Time	0	Other	Heirloom	$400.00	1	20	3	3
              Full-Time	1-2	Wedding	Essential	$500.00	2	5	12	3
              Full-Time	1-2	Wedding	Keepsake	$600.00	2	10	12	3
              Full-Time	1-2	Wedding	Heirloom	$700.00	2	20	12	3
              Full-Time	1-2	Family	Essential	$800.00	1	5	3	3
              Full-Time	1-2	Family	Keepsake	$900.00	1	10	3	3
              Full-Time	1-2	Family	Heirloom	$1,000.00	1	20	3	3
              Full-Time	1-2	Event	Essential	$1,100.00	1	5	3	3
              Full-Time	1-2	Event	Keepsake	$1,200.00	1	10	3	3
              Full-Time	1-2	Event	Heirloom	$1,300.00	1	20	3	3
              Full-Time	0	Wedding	Essential	$1,4000.00	2	5	12	3
              Full-Time	0	Wedding	Keepsake	$1,5000.00	2	10	12	3
              Full-Time	0	Wedding	Heirloom	$1,6000.00	2	20	12	3
              """
              |> String.trim(),
            cost_of_living: """
            state percent
            IL	-8%
            OK	-3%
            """
          }
        ) do
          {:picsello |> Application.get_env(:packages) |> get_in([:calculator, name]), tsv}
        end

      Picsello.Mock.mock_google_sheets(csvs)

      Picsello.Workers.SyncTiers.perform(nil)

      Packages.create_initial(user)

      %{organization: %{package_templates: templates}} =
        Repo.preload(user, organization: :package_templates)

      assert [
               %{
                 name: "Essential Event",
                 base_price: %Money{amount: 106_500},
                 print_credits: %Money{amount: 0},
                 buy_all: nil,
                 download_count: 5,
                 shoot_count: 1,
                 turnaround_weeks: 3
               },
               %{
                 name: "Essential Wedding",
                 base_price: %Money{amount: 48_500},
                 print_credits: %Money{amount: 0},
                 buy_all: nil,
                 download_count: 5,
                 shoot_count: 2,
                 turnaround_weeks: 12
               },
               %{
                 name: "Heirloom Event",
                 base_price: %Money{amount: 126_000},
                 print_credits: %Money{amount: 0},
                 buy_all: nil,
                 download_count: 20,
                 shoot_count: 1,
                 turnaround_weeks: 3
               },
               %{
                 name: "Heirloom Wedding",
                 base_price: %Money{amount: 68_000},
                 print_credits: %Money{amount: 0},
                 buy_all: nil,
                 download_count: 20,
                 shoot_count: 2,
                 turnaround_weeks: 12
               },
               %{
                 name: "Keepsake Event",
                 base_price: %Money{amount: 116_500},
                 print_credits: %Money{amount: 0},
                 buy_all: nil,
                 download_count: 10,
                 shoot_count: 1,
                 turnaround_weeks: 3
               },
               %{
                 name: "Keepsake Wedding",
                 base_price: %Money{amount: 58_000},
                 print_credits: %Money{amount: 0},
                 buy_all: nil,
                 download_count: 10,
                 shoot_count: 2,
                 turnaround_weeks: 12
               }
             ] = templates |> Enum.sort_by(& &1.name)
    end
  end
end
