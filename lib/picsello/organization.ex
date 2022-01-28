defmodule Picsello.Organization do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  alias Picsello.{Package, Campaign, Client, Accounts.User, Repo, Profiles.Profile}

  schema "organizations" do
    field(:name, :string)
    field(:stripe_account_id, :string)
    field(:slug, :string)
    field(:previous_slug, :string)
    embeds_one(:profile, Profile, on_replace: :update)

    has_many(:package_templates, Package, where: [package_template_id: nil])
    has_many(:campaigns, Campaign)
    has_many(:clients, Client)
    has_one(:user, User)

    timestamps()
  end

  def registration_changeset(organization, attrs, "" <> user_name),
    do:
      registration_changeset(
        organization,
        Map.put_new(attrs, :name, "#{user_name} Photography")
      )

  def registration_changeset(organization, attrs, _user_name),
    do: registration_changeset(organization, attrs)

  def registration_changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name])
    |> prepare_changes(fn changeset ->
      case get_field(changeset, :slug) do
        nil -> put_change(changeset, :slug, changeset |> get_field(:name) |> build_slug())
        _ -> changeset
      end
    end)
    |> unique_constraint(:slug)
  end

  def name_changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> prepare_changes(fn changeset ->
      changeset
      |> put_change(:previous_slug, changeset |> get_field(:slug))
      |> put_change(:slug, changeset |> get_field(:name) |> build_slug())
    end)
    |> unique_constraint(:slug)
  end

  def edit_profile_changeset(organization, attrs) do
    organization
    |> cast(attrs, [])
    |> cast_embed(:profile)
  end

  def assign_stripe_account_changeset(%__MODULE__{} = organization, "" <> stripe_account_id),
    do: organization |> change(stripe_account_id: stripe_account_id)

  def build_slug(name) do
    slug = name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
    slug_like = "#{slug}%"

    highest_slug_index =
      from(organization in __MODULE__,
        where: like(organization.slug, ^slug_like),
        select:
          "(coalesce(regexp_match(?, '\\d+$'), ARRAY['1']))[1]::int"
          |> fragment(organization.slug)
          |> max()
      )
      |> Repo.one()

    case highest_slug_index do
      nil -> slug
      n -> "#{slug}-#{n + 1}"
    end
  end
end
