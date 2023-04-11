defmodule Picsello.FactoryReset do
  @moduledoc false

  alias Picsello.{
    Repo,
    Accounts.User,
    Accounts.UserToken,
    Packages,
    SubscriptionEvent,
    OrganizationCard,
    Organization,
    GlobalSettings,
    GlobalSettings.GalleryProduct,
    OrganizationJobType,
    Profiles.Profile
  }

  alias Ecto.{Multi}
  import Ecto.{Changeset, Query}

  @user_fields [
    :confirmed_at,
    :email,
    :hashed_password,
    :name,
    :allow_cash_payment,
    :time_zone,
    :sign_up_auth_provider,
    :stripe_customer_id
  ]

  @profile_fields [:job_types, :color, :is_enabled]
  @org_fields [:name, :stripe_account_id, :slug, :previous_slug]
  @onboarding_fields [:photographer_years, :schedule, :state, :completed_at]

  @cards ~w(set-up-stripe open-user-settings)

  def start(user_id) do
    %{
      organization:
        %{
          organization_cards: ex_cards,
          organization_job_types: org_job_types,
          profile: profile,
          name: name
        } = organization,
      subscription_event: subscription_event,
      onboarding: onboarding,
      email: email
    } =
      user =
      User
      |> where(id: ^user_id)
      |> preload([
        :subscription_event,
        organization: [:organization_job_types, organization_cards: [:card]]
      ])
      |> Repo.one()

    organization
    |> Map.take(@org_fields)
    |> Map.merge(%{
      profile: Map.take(profile, @profile_fields),
      slug: Organization.build_slug(name),
      organization_cards: organization_cards(ex_cards),
      gs_gallery_products: GlobalSettings.gallery_products_params()
    })
    |> then(fn organization ->
      user
      |> Map.take(@user_fields)
      |> Map.put(:onboarding, Map.take(onboarding, @onboarding_fields))
      |> Map.put(:organization, organization)
    end)
    |> then(fn %{onboarding: onboarding} = user_attrs ->
      ex_user = %{email: "#{email}-#{UUID.uuid4()}", stripe_customer_id: nil, deleted_at: now()}

      Multi.new()
      |> Ecto.Multi.delete_all(:tokens, UserToken.user_and_contexts_query(user, :all))
      |> Multi.update(:ex_user, change(user, ex_user))
      |> Multi.insert(
        :user,
        %User{}
        |> cast(user_attrs, @user_fields)
        |> put_embed(:onboarding, onboarding)
        |> cast_assoc(:organization, with: &registration_changeset/2)
      )
      |> organization_job_type_multi(:show_on_profile?, org_job_types)
      |> organization_job_type_multi(:show_on_business?, org_job_types)
      |> Multi.run(:packages, fn _repo, %{user: user} ->
        Packages.create_initial(user)
        {:ok, ""}
      end)
    end)
    |> then(fn
      multi when not is_nil(subscription_event) ->
        multi
        |> Multi.insert(:subscription_event, fn
          %{user: user} ->
            subscription_event
            |> Map.from_struct()
            |> Map.put(:user_id, user.id)
            |> SubscriptionEvent.create_changeset()
        end)

      multi ->
        multi
    end)
    |> Repo.transaction()
  end

  def registration_changeset(changeset, attrs) do
    changeset
    |> cast(attrs, @org_fields)
    |> cast_embed(:profile, with: &Profile.changeset_for_factory_reset/2)
    |> cast_assoc(:organization_cards, with: &OrganizationCard.changeset/2)
    |> cast_assoc(:gs_gallery_products, with: &GalleryProduct.changeset/2)
  end

  defp organization_cards(ex_cards) do
    for %{card: card} = org_card <- ex_cards, card.concise_name in @cards do
      org_card
      |> Map.from_struct()
      |> Map.put(:data, %{})
    end
    |> then(fn stripe_cards ->
      ids = Enum.map(stripe_cards, & &1.card_id)

      OrganizationCard.for_new_changeset()
      |> Enum.reject(&(&1.card_id in ids))
      |> Enum.concat(stripe_cards)
    end)
  end

  defp organization_job_type_multi(multi, key, job_types) do
    job_types = job_types |> Enum.filter(&Map.get(&1, key)) |> Enum.map(& &1.job_type)

    multi
    |> Multi.update_all(
      key,
      fn %{user: %{organization: %{id: new_org_id}}} ->
        OrganizationJobType
        |> where(organization_id: ^new_org_id)
        |> where([o], o.job_type in ^job_types)
      end,
      set: Keyword.put([], key, true)
    )
  end

  defp now(), do: DateTime.utc_now() |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)
end
