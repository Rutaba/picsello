defmodule Picsello.Organization do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias Picsello.{
    PackagePaymentPreset,
    OrganizationJobType,
    OrganizationCard,
    Package,
    Utils,
    Campaign,
    Client,
    Accounts.User,
    Repo,
    Profiles.Profile,
    GlobalSettings.GalleryProduct
  }

  defmodule EmailSignature do
    @moduledoc false
    use Ecto.Schema
    @primary_key false
    embedded_schema do
      field(:show_phone, :boolean, default: true)
      field(:content, :string)
    end

    def changeset(signature, attrs) do
      signature
      |> cast(attrs, [:show_phone, :content])
    end
  end

  schema "organizations" do
    field(:name, :string)
    field(:stripe_account_id, :string)
    field(:slug, :string)
    field(:previous_slug, :string)

    embeds_one(:profile, Profile, on_replace: :update)
    embeds_one(:email_signature, EmailSignature, on_replace: :update)

    has_many(:package_templates, Package, where: [package_template_id: nil])
    has_many(:campaigns, Campaign)
    has_many(:package_payment_presets, PackagePaymentPreset)
    has_many(:brand_links, Picsello.BrandLink)
    has_many(:clients, Client)
    has_many(:organization_cards, OrganizationCard)
    has_many(:gs_gallery_products, GalleryProduct)
    has_many(:organization_job_types, OrganizationJobType, on_replace: :delete)
    has_one(:global_setting, Picsello.GlobalSettings.Gallery)
    has_one(:user, User)

    timestamps()
  end

  @type t :: %__MODULE__{name: String.t()}

  def email_signature_changeset(organization, attrs) do
    organization
    |> cast(attrs, [])
    |> cast_embed(:email_signature)
  end

  def registration_changeset(organization, attrs, "" <> user_name),
    do:
      registration_changeset(
        organization,
        Map.put_new(
          attrs,
          :name,
          build_organization_name("#{user_name} Photography")
          |> Utils.capitalize_all_words()
        )
      )

  def registration_changeset(organization, attrs, _user_name),
    do: registration_changeset(organization, attrs)

  def registration_changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name, :slug])
    |> cast_assoc(:organization_cards, with: &OrganizationCard.changeset/2)
    |> cast_assoc(:gs_gallery_products, with: &GalleryProduct.changeset/2)
    |> cast_assoc(:organization_job_types, with: &OrganizationJobType.changeset/2)
    |> validate_required([:name])
    |> validate_org_name()
    |> prepare_changes(fn changeset ->
      case get_change(changeset, :slug) do
        nil ->
          change_slug(changeset)

        _ ->
          changeset
      end
    end)
    |> unique_constraint(:slug)
  end

  defp validate_org_name(changeset) do
    case get_field(changeset, :name) do
      nil ->
        changeset

      name ->
        updated_name = name |> String.trim() |> String.downcase()
        names = Repo.all(from o in __MODULE__, select: o.name)
        existing_names = Enum.map(names, &String.downcase/1)

        case Enum.member?(existing_names, updated_name) do
          true ->
            changeset |> add_error(:name, "already exists")

          false ->
            changeset
        end
    end
  end

  def name_changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_org_name()
    |> prepare_changes(&change_slug/1)
    |> unique_constraint(:slug)
    |> case do
      %{changes: %{name: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :name, "")
    end
  end

  def edit_profile_changeset(organization, attrs) do
    organization
    |> cast(attrs, [])
    |> cast_embed(:profile)
  end

  def assign_stripe_account_changeset(%__MODULE__{} = organization, "" <> stripe_account_id),
    do: organization |> change(stripe_account_id: stripe_account_id)

  def build_organization_name(name) do
    converted_name =
      String.downcase(name)
      |> String.replace(~r/[^a-z0-9]+/, " ")
      |> String.trim("-")

    find_unique_organization_name(converted_name)
  end

  defp find_unique_organization_name(name, count \\ 0) do
    updated_name =
      if count > 0 do
        "#{name} #{count}"
      else
        name
      end

    names =
      Repo.all(from o in __MODULE__, select: o.name)

    existing_names = Enum.map(names, &String.downcase/1)

    case Enum.member?(existing_names, updated_name) do
      true ->
        find_unique_organization_name(name, count + 1)

      false ->
        updated_name
    end
  end

  def build_slug(name) do
    String.downcase(name) |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
  end

  defp change_slug(changeset),
    do:
      changeset
      |> put_change(:previous_slug, get_field(changeset, :slug))
      |> put_change(:slug, changeset |> get_field(:name) |> build_slug())
end
