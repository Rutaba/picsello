defmodule Picsello.Profiles do
  @moduledoc "context module for public photographer profile"
  import Ecto.Query, only: [from: 2]
  alias Picsello.{Repo, Organization, Job, ClientMessage}

  defmodule Contact do
    @moduledoc "container for the contact form data"
    use Ecto.Schema
    import Ecto.Changeset
    import Picsello.Client, only: [valid_phone: 2]
    import Picsello.Accounts.User, only: [validate_email_format: 1]

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

  def handle_contact(%{id: organization_id} = _organization, params) do
    changeset = contact_changeset(params)

    case changeset do
      %{valid?: true} ->
        contact = Ecto.Changeset.apply_changes(changeset)

        {:ok, _} =
          Ecto.Multi.new()
          |> Ecto.Multi.insert(
            :lead,
            Job.create_changeset(%{
              type: contact.job_type,
              client:
                contact
                |> Map.take([:name, :email, :phone])
                |> Map.put(:organization_id, organization_id)
            })
          )
          |> Ecto.Multi.insert(
            :message,
            &ClientMessage.create_inbound_changeset(%{
              job_id: &1.lead.id,
              subject: "New lead from profile",
              body_text: contact.message
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
      where: o.slug == ^slug,
      preload: [:user]
    )
    |> Repo.one!()
  end
end
