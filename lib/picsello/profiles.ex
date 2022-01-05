defmodule Picsello.Profiles do
  @moduledoc "context module for public photographer profile"
  import Ecto.Query, only: [from: 2]
  alias Picsello.{Repo, Organization, Job, JobType, ClientMessage, Client, Accounts.User}

  defmodule Profile do
    @moduledoc "used to render the organization public profile"
    use Ecto.Schema
    import Ecto.Changeset

    @colors ~w(#5C6578 #3376FF #3AE7C7 #E466F8 #1AD0DC #FFD80D #F8AC66 #9566F8)
    @default_color hd(@colors)

    def colors(), do: @colors

    def default_color(), do: @default_color

    @primary_key false
    embedded_schema do
      field :is_enabled, :boolean, default: true
      field(:color, :string)
      field(:job_types, {:array, :string})
      field(:no_website, :boolean, default: false)
      field(:website, :string)
      field(:description, :string)
    end

    def enabled?(%__MODULE__{is_enabled: is_enabled}), do: is_enabled

    def changeset(%__MODULE__{} = profile, attrs) do
      profile
      |> cast(attrs, [:no_website, :website, :color, :job_types, :description])
      |> then(
        &if get_field(&1, :no_website),
          do: put_change(&1, :website, nil),
          else: &1
      )
      |> prepare_changes(&clean_job_types/1)
      |> validate_change(:website, &for(e <- url_validation_errors(&2), do: {&1, e}))
    end

    defp url_validation_errors(url) do
      case URI.parse(url) do
        %{scheme: nil} ->
          ("https://" <> url) |> url_validation_errors()

        %{scheme: scheme, host: "" <> host} when scheme in ["http", "https"] ->
          label = "[a-zA-Z0-9\\-]{1,63}+"

          if "^(?:(?:#{label})\\.)+(?:#{label})$"
             |> Regex.compile!()
             |> Regex.match?(host),
             do: [],
             else: ["is invalid"]

        %{scheme: _scheme} ->
          ["is invalid"]
      end
    end

    defp clean_job_types(changeset) do
      update_change(changeset, :job_types, fn
        list -> list |> Enum.filter(&(&1 != "")) |> Enum.uniq() |> Enum.sort()
      end)
    end
  end

  defmodule Contact do
    @moduledoc "container for the contact form data"
    use Ecto.Schema
    import Ecto.Changeset
    import Picsello.Client, only: [valid_phone: 2]
    import Picsello.Accounts.User, only: [validate_email_format: 1]
    import PicselloWeb.Gettext

    @fields ~w[name email phone job_type message]a

    embedded_schema do
      for field <- @fields do
        field field, :string
      end
    end

    def changeset(%__MODULE__{} = contact, attrs) do
      contact
      |> cast(attrs, @fields)
      |> validate_email_format()
      |> validate_required(@fields)
      |> validate_change(:phone, &valid_phone/2)
    end

    def to_string(%__MODULE__{} = contact) do
      """
          name: #{contact.name}
         email: #{contact.email}
         phone: #{contact.phone}
      job type: #{dyn_gettext(contact.job_type)}
       message: #{contact.message}
      """
    end
  end

  def contact_changeset(contact, attrs) do
    Contact.changeset(contact, attrs)
  end

  def contact_changeset(attrs) do
    Contact.changeset(%Contact{}, attrs)
  end

  def contact_changeset() do
    Contact.changeset(%Contact{}, %{})
  end

  def edit_organization_profile_changeset(%Organization{} = organization, attrs) do
    Organization.edit_profile_changeset(organization, attrs)
  end

  def update_organization_profile(%Organization{} = organization, attrs) do
    organization |> edit_organization_profile_changeset(attrs) |> Repo.update()
  end

  def handle_contact(%{id: organization_id} = _organization, params) do
    changeset = contact_changeset(params)

    case changeset do
      %{valid?: true} ->
        contact = Ecto.Changeset.apply_changes(changeset)

        {:ok, _} =
          Ecto.Multi.new()
          |> Ecto.Multi.insert(
            :client,
            contact
            |> Map.take([:name, :email, :phone])
            |> Map.put(:organization_id, organization_id)
            |> Client.create_changeset(),
            on_conflict: {:replace, [:email]},
            conflict_target: [:organization_id, :email],
            returning: [:id]
          )
          |> Ecto.Multi.insert(
            :lead,
            &Job.create_changeset(%{type: contact.job_type, client_id: &1.client.id})
          )
          |> Ecto.Multi.insert(
            :message,
            &ClientMessage.create_inbound_changeset(%{
              job_id: &1.lead.id,
              subject: "New lead from profile",
              body_text: Contact.to_string(contact)
            })
          )
          |> Repo.transaction()

        {:ok, contact}

      _ ->
        {:error, Map.put(changeset, :action, :validate)}
    end
  end

  def find_organization_by(slug: slug) do
    from(
      o in Organization,
      where: o.slug == ^slug and fragment("coalesce((profile -> 'is_enabled')::boolean, true)"),
      preload: [:user]
    )
    |> Repo.one!()
  end

  def find_organization_by(user: %User{} = user) do
    user |> Repo.preload(organization: :user) |> Map.get(:organization)
  end

  def enabled?(%Organization{profile: profile}), do: Profile.enabled?(profile)

  def toggle(%Organization{} = organization) do
    organization
    |> Ecto.Changeset.change(%{profile: %{is_enabled: !enabled?(organization)}})
    |> Repo.update!()
  end

  defdelegate colors(), to: Profile
  defdelegate job_types(), to: JobType, as: :all

  def color(%Organization{profile: %{color: color}}), do: color
  def color(_), do: Profile.default_color()

  def public_url(%Organization{slug: slug}) do
    PicselloWeb.Router.Helpers.profile_url(PicselloWeb.Endpoint, :index, slug)
  end
end
