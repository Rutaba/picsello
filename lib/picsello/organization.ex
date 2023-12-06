defmodule Picsello.Organization do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

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
    GlobalSettings.GalleryProduct,
    Address,
    PreferredFilter
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

  defmodule PaymentOptions do
    @moduledoc false
    use Ecto.Schema
    @primary_key false

    embedded_schema do
      field(:allow_cash, :boolean, default: false)
      field(:allow_affirm, :boolean, default: false)
      field(:allow_afterpay_clearpay, :boolean, default: false)
      field(:allow_klarna, :boolean, default: false)
      field(:allow_cashapp, :boolean, default: false)
    end

    def changeset(payment_options, attrs) do
      payment_options
      |> cast(attrs, [
        :allow_cash,
        :allow_affirm,
        :allow_afterpay_clearpay,
        :allow_klarna,
        :allow_cashapp
      ])
    end
  end

  defmodule ClientProposal do
    @moduledoc false
    use Ecto.Schema
    @primary_key false

    embedded_schema do
      field(:title, :string)
      field(:booking_panel_title, :string)
      field(:message, :string)
      field(:contact_button, :string)
    end

    def changeset(proposal, attrs) do
      proposal
      |> cast(attrs, [:title, :booking_panel_title, :message, :contact_button])
      |> validate_required([:title, :booking_panel_title, :message, :contact_button],
        message: "should not be empty"
      )
      |> validate_field(:title, min: 5, max: 30)
      |> validate_field(:booking_panel_title, min: 10, max: 50)
      |> validate_field(:contact_button, min: 5, max: 35)
    end

    defp validate_field(changeset, field, min: min, max: max) do
      check_field = get_field(changeset, field)

      cond do
        String.length(check_field) < min ->
          add_error(changeset, field, "must be greater than #{min} characters")

        String.length(check_field) > max ->
          add_error(changeset, field, "must be less than #{max} characters")

        !Regex.match?(~r/[A-Za-z]/, check_field) ->
          add_error(changeset, field, "has invalide format")

        true ->
          changeset
      end
    end
  end

  schema "organizations" do
    field(:name, :string)
    field(:stripe_account_id, :string)
    field(:slug, :string)
    field(:previous_slug, :string)
    field(:global_automation_enabled, :boolean, default: true)
    embeds_one(:profile, Profile, on_replace: :update)
    embeds_one(:email_signature, EmailSignature, on_replace: :update)
    embeds_one(:payment_options, PaymentOptions, on_replace: :update)
    embeds_one(:client_proposal, ClientProposal, on_replace: :update)

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
    has_one(:address, Address, on_replace: :update)
    has_one(:preferred_filters, PreferredFilter, on_replace: :update)

    timestamps()
  end

  @type t :: %__MODULE__{name: String.t()}

  def email_signature_changeset(organization, attrs) do
    organization
    |> cast(attrs, [])
    |> cast_embed(:email_signature)
  end

  def client_proposal_portal_changeset(organization, attrs) do
    organization
    |> cast(attrs, [])
    |> cast_embed(:client_proposal)
  end

  def address_changeset(organization, attrs) do
    organization
    |> cast(attrs, [])
    |> cast_assoc(:address, required: true)
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
    |> then(fn changeset ->
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
    name = get_change(changeset, :name)

    if name && check_existing_name_and_slug(name, build_slug(name)) do
      add_error(
        changeset,
        :name,
        "Business name already exists. Please try with a different name."
      )
    else
      changeset
    end
  end

  def name_changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> prepare_changes(&change_slug/1)
    |> validate_org_name()
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

  def payment_options_changeset(organization, attrs) do
    organization
    |> cast(attrs, [])
    |> cast_embed(:payment_options)
  end

  def assign_stripe_account_changeset(%__MODULE__{} = organization, "" <> stripe_account_id),
    do: organization |> change(stripe_account_id: stripe_account_id)

  defp build_organization_name(name) do
    name
    |> reformat_string()
    |> find_unique_organization_name()
  end

  @spec find_unique_organization_name(name :: String.t(), count :: integer) :: String.t()
  defp find_unique_organization_name(name, count \\ 0) do
    updated_name =
      if count > 0 do
        "#{name} #{count}"
      else
        name
      end

    updated_slug = build_slug(updated_name)

    if check_existing_name_and_slug(updated_name, updated_slug) do
      find_unique_organization_name(name, count + 1)
    else
      updated_name
    end
  end

  def build_slug(nil), do: nil

  def build_slug(name), do: reformat_string(name, "-")

  @spec check_existing_name_and_slug(name :: String.t(), slug :: String.t()) :: boolean
  defp check_existing_name_and_slug(name, slug) do
    Repo.exists?(
      from o in __MODULE__,
        where:
          fragment(
            "LOWER(?) = LOWER(?) OR LOWER(?) = LOWER(?)",
            o.name,
            ^name,
            o.slug,
            ^slug
          ),
        limit: 1
    )
  end

  @spec reformat_string(name :: String.t(), replace_by :: String.t()) :: String.t()
  defp reformat_string(name, replace_by \\ " "),
    do:
      name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, replace_by) |> String.trim("-")

  defp change_slug(changeset),
    do:
      changeset
      |> put_change(:previous_slug, get_field(changeset, :slug))
      |> put_change(:slug, changeset |> get_field(:name) |> build_slug())
end

# global_automation_enabled default true

# when turns off
# disable all automation emails for this organization
# -> for manuall trigger emails confirm case when all emails diabsle how they works
# -> if no email found then fetch default email where org_id nil
# stopped all active emails with condition :gloabally_stopped
# when turns on
# enable all disabled emails for this organization
# revert all those emails which have gloabally_stopped
