defmodule Picsello.Onboardings do
  @moduledoc "context module for photographer onboarding"
  alias Picsello.{Repo, Accounts.User, Organization, Profiles.Profile}
  import Ecto.Changeset
  import Picsello.Accounts.User, only: [put_new_attr: 3, update_attr_in: 3]
  import Ecto.Query, only: [from: 2]

  defmodule Onboarding do
    @moduledoc "Container for user specific onboarding info. Embedded in users table."

    use Ecto.Schema

    defmodule IntroState do
      @moduledoc "Container for user specific introjs state. Embedded in onboarding embed."
      use Ecto.Schema

      embedded_schema do
        field(:changed_at, :utc_datetime)
        field(:state, Ecto.Enum, values: [:completed, :dismissed, :restarted])
      end
    end

    @software_options [
      sprout_studio: "Sprout Studio",
      pixieset: "Pixieset",
      shootproof: "Shootproof",
      honeybook: "Honeybook",
      session: "Session",
      other: "Other",
      none: "None"
    ]

    @primary_key false
    embedded_schema do
      field(:phone, :string)
      field(:photographer_years, :integer)

      field(:switching_from_softwares, {:array, Ecto.Enum},
        values: Keyword.keys(@software_options)
      )

      field(:schedule, Ecto.Enum, values: [:full_time, :part_time])
      field(:completed_at, :utc_datetime)
      field(:state, :string)
      embeds_many(:intro_states, IntroState)
    end

    def changeset(%__MODULE__{} = onboarding, attrs) do
      onboarding
      |> cast(attrs, [
        :phone,
        :schedule,
        :photographer_years,
        :switching_from_softwares,
        :state
      ])
      |> validate_required([:state, :photographer_years, :schedule, :phone])
      |> validate_change(:phone, &valid_phone/2)
    end

    def completed?(%__MODULE__{completed_at: nil}), do: false
    def completed?(%__MODULE__{}), do: true
    defdelegate valid_phone(field, value), to: Picsello.Client

    def software_options(), do: @software_options
  end

  defdelegate software_options(), to: Onboarding

  def changeset(%User{} = user, attrs, opts \\ []) do
    step = Keyword.get(opts, :step, 6)

    user
    |> cast(
      attrs
      |> put_new_attr(:onboarding, %{})
      |> update_attr_in(
        [:organization],
        &((&1 || %{}) |> put_new_attr(:profile, %{}) |> put_new_attr(:id, user.organization_id))
      ),
      []
    )
    |> cast_embed(:onboarding, with: &onboarding_changeset(&1, &2, step), required: true)
    |> cast_assoc(:organization,
      with: &organization_onboarding_changeset(&1, &2, step),
      required: true
    )
  end

  def state_options(),
    do:
      from(adjustment in Picsello.Packages.CostOfLivingAdjustment,
        select: adjustment.state,
        order_by: adjustment.state
      )
      |> Repo.all()
      |> Enum.map(&{&1, &1})

  def complete!(user),
    do:
      user
      |> tap(&Picsello.Packages.create_initial/1)
      |> User.complete_onboarding_changeset()
      |> Repo.update!()

  def save_intro_state(current_user, intro_id, state) do
    new_intro_state = %Onboarding.IntroState{
      changed_at: DateTime.utc_now(),
      state: state,
      id: intro_id
    }

    current_user
    |> cast(%{onboarding: %{}}, [])
    |> cast_embed(:onboarding,
      with: fn %{intro_states: intro_states} = onboarding, _ ->
        onboarding
        |> change()
        |> put_embed(:intro_states, [
          new_intro_state | Enum.filter(intro_states, &(&1.id != intro_id))
        ])
      end
    )
    |> Repo.update!()
  end

  def show_intro?(current_user, intro_id) do
    for(
      %{id: ^intro_id, state: state} when state in [:completed, :dismissed] <-
        current_user.onboarding.intro_states,
      reduce: true
    ) do
      _ -> false
    end
  end

  defp organization_onboarding_changeset(organization, attrs, step) do
    organization
    |> Organization.registration_changeset(attrs)
    |> cast_embed(:profile, required: step > 2, with: &profile_onboarding_changeset(&1, &2, step))
  end

  defp profile_onboarding_changeset(profile, attrs, 2), do: Profile.changeset(profile, attrs)

  defp profile_onboarding_changeset(profile, attrs, 3) do
    profile
    |> profile_onboarding_changeset(attrs, 2)
    |> validate_required([:job_types])
    |> validate_length(:job_types, min: 1)
  end

  defp profile_onboarding_changeset(profile, attrs, step) when step in [4, 5, 6] do
    profile
    |> profile_onboarding_changeset(attrs, 3)
    |> validate_required([:color])
    |> then(&if get_field(&1, :no_website), do: &1, else: validate_required(&1, [:website]))
  end

  defp onboarding_changeset(onboarding, attrs, 5) do
    onboarding
    |> onboarding_changeset(attrs, 4)
    |> validate_required([:switching_from_softwares])
    |> validate_length(:switching_from_softwares, min: 1)
    |> update_change(
      :switching_from_softwares,
      &if(Enum.member?(&1, :none), do: [:none], else: &1)
    )
  end

  defp onboarding_changeset(onboarding, attrs, _) do
    Onboarding.changeset(onboarding, attrs)
  end
end
