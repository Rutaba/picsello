defmodule Picsello.OnboardingsTest do
  use Picsello.DataCase, async: true

  alias Picsello.{Onboardings, Accounts.User}
  alias Ecto.Changeset

  describe "changeset" do
    def changeset_errors(user, attrs, options) do
      user
      |> Onboardings.changeset(attrs, options)
      |> Changeset.traverse_errors(fn _changeset, _field, {_, [{_, validation}]} ->
        validation
      end)
    end

    test "step 2 requires org name, schedule, photographer years, state, and phone" do
      user = insert(:user)

      assert %{
               onboarding: %{
                 phone: [:required],
                 photographer_years: [:required],
                 schedule: [:required],
                 state: [:required]
               },
               organization: %{name: [:required]} = organization_errors
             } =
               changeset_errors(
                 user,
                 %{onboarding: %{}, organization: %{id: user.organization_id, name: nil}},
                 step: 2
               )

      assert 1 = map_size(organization_errors)
    end

    test "step 3 requires job type(s)" do
      user = insert(:user)

      assert %{
               onboarding: %{
                 phone: [:required],
                 photographer_years: [:required],
                 schedule: [:required],
                 state: [:required]
               },
               organization: %{
                 name: [:required],
                 profile:
                   %{
                     job_types: [:required]
                   } = profile_errors
               }
             } =
               changeset_errors(
                 user,
                 %{
                   onboarding: %{},
                   organization: %{id: user.organization_id, name: nil, profile: %{}}
                 },
                 step: 3
               )

      assert [:job_types] = Map.keys(profile_errors)
    end

    test "step 4 requires color, website" do
      user = insert(:user)

      assert %{
               onboarding: %{
                 phone: [:required],
                 photographer_years: [:required],
                 schedule: [:required],
                 state: [:required]
               },
               organization: %{
                 name: [:required],
                 profile: %{
                   website: [:required],
                   job_types: [:required],
                   color: [:required]
                 }
               }
             } =
               changeset_errors(
                 user,
                 %{
                   onboarding: %{},
                   organization: %{id: user.organization_id, name: nil, profile: %{}}
                 },
                 step: 4
               )
    end

    test "step 5 requires switching from softwares" do
      user = insert(:user)

      assert %{
               onboarding: %{
                 phone: [:required],
                 photographer_years: [:required],
                 schedule: [:required],
                 state: [:required],
                 switching_from_softwares: [:required]
               },
               organization: %{
                 name: [:required],
                 profile: %{
                   website: [:required],
                   job_types: [:required],
                   color: [:required]
                 }
               }
             } =
               changeset_errors(
                 user,
                 %{
                   onboarding: %{},
                   organization: %{id: user.organization_id, name: nil, profile: %{}}
                 },
                 step: 5
               )
    end

    test "validates website" do
      assert [["is invalid"], nil, nil, ["is invalid"]] =
               for(
                 url <- [
                   "ftp://example.com",
                   "example.com",
                   "example.com/my-profile",
                   "https://bad!.hostname"
                 ],
                 do:
                   %User{}
                   |> Onboardings.changeset(%{organization: %{profile: %{website: url}}})
                   |> errors_on()
                   |> get_in([:organization, :profile, :website])
               )
    end
  end
end
