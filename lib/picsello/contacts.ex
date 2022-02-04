defmodule Picsello.Contacts do
  @moduledoc "context module for contacts"
  import Ecto.Query, only: [from: 2]
  alias Picsello.{Repo, Client}

  def find_all_by(user: user) do
    from(c in Client,
      where: c.organization_id == ^user.organization_id and is_nil(c.archived_at),
      order_by: [asc: c.name, asc: c.email]
    )
    |> Repo.all()
  end

  def new_contact_changeset(attrs, organization_id) do
    attrs
    |> Map.put("organization_id", organization_id)
    |> Client.create_contact_changeset()
  end

  def edit_contact_changeset(contact, attrs) do
    Client.edit_contact_changeset(contact, attrs)
  end

  def save_new_contact(attrs, organization_id) do
    new_contact_changeset(attrs, organization_id) |> Repo.insert()
  end

  def save_contact(contact, attrs) do
    edit_contact_changeset(contact, attrs) |> Repo.update()
  end

  def archive_contact(id) do
    Repo.get(Client, id)
    |> Client.archive_changeset()
    |> Repo.update()
  end
end
