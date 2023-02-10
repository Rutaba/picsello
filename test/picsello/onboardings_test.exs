defmodule Picsello.OnboardingsTest do
  use Picsello.DataCase, async: true

  alias Picsello.{Onboardings}
  alias Ecto.Changeset

  describe "changeset" do
    def changeset_errors(user, attrs, options) do
      user
      |> Onboardings.changeset(attrs, options)
      |> Changeset.traverse_errors(fn _changeset, _field, {_message, meta} ->
        Keyword.get(meta, :validation)
      end)
    end

    test "step 2 requires org name, schedule, photographer years, and state" do
      user = insert(:user)

      assert %{
               onboarding: %{
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
                 photographer_years: [:required],
                 schedule: [:required],
                 state: [:required]
               },
               organization: %{
                 name: [:required],
                 organization_job_types: [:required]
               }
             } ==
               changeset_errors(
                 user,
                 %{
                   onboarding: %{},
                   organization: %{id: user.organization_id, name: nil, profile: %{}}
                 },
                 step: 3
               )
    end
  end

  describe "save_intro_state" do
    test "persists intro_id, time of action, and new state" do
      user = :user |> insert() |> Picsello.Onboardings.save_intro_state("intro_id_1", "completed")

      assert %{
               onboarding: %{
                 intro_states: [%{id: "intro_id_1", changed_at: %DateTime{}, state: :completed}]
               }
             } = Repo.reload(user)
    end

    test "adds a subsequent intro entry for multiple usage" do
      user =
        :user
        |> insert()
        |> Picsello.Onboardings.save_intro_state("intro_id_2", "dismissed")
        |> Picsello.Onboardings.save_intro_state("intro_id_3", "restarted")

      assert %{
               onboarding: %{
                 intro_states: [
                   %{id: "intro_id_3", changed_at: %DateTime{}, state: :restarted},
                   %{id: "intro_id_2", changed_at: %DateTime{}, state: :dismissed}
                 ]
               }
             } = Repo.reload(user)
    end

    test "adds an intro entry and then updates it" do
      user =
        :user
        |> insert()
        |> Picsello.Onboardings.save_intro_state("intro_id_4", "dismissed")
        |> Picsello.Onboardings.save_intro_state("intro_id_4", "completed")

      assert %{
               onboarding: %{
                 intro_states: [
                   %{id: "intro_id_4", changed_at: %DateTime{}, state: :dismissed}
                 ]
               }
             } = Repo.reload(user)
    end
  end
end
