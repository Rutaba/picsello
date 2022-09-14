defmodule Picsello.Jobs do
  @moduledoc "context module for jobs"
  alias Picsello.{
    Accounts.User,
    Repo,
    Client,
    Job
  }

  def archive_lead(%Job{} = job) do
    job |> Job.archive_changeset() |> Repo.update()
  end

  def maybe_upsert_client(%Ecto.Multi{} = multi, %Client{} = new_client, %User{} = current_user) do
    old_client =
      Repo.get_by(Client,
        email: new_client.email |> String.downcase(),
        organization_id: current_user.organization_id
      )

    maybe_upsert_client(multi, old_client, new_client, current_user.organization_id)
  end

  defp maybe_upsert_client(
         multi,
         %Client{id: id, name: name, phone: phone} = old_client,
         new_client,
         _organization_id
       )
       when id != nil and (name == nil or phone == nil) do
    attrs =
      old_client
      |> Map.take([:name, :phone])
      |> Enum.filter(fn {_, v} -> v != nil end)
      |> Enum.into(%{name: new_client.name, phone: new_client.phone})

    Ecto.Multi.update(multi, :client, Client.edit_contact_changeset(old_client, attrs))
  end

  defp maybe_upsert_client(multi, %Client{id: id} = old_client, _new_client, _organization_id)
       when id != nil do
    Ecto.Multi.put(multi, :client, old_client)
  end

  defp maybe_upsert_client(multi, nil = _old_client, new_client, organization_id) do
    Ecto.Multi.insert(
      multi,
      :client,
      new_client
      |> Map.take([:name, :email, :phone])
      |> Map.put(:organization_id, organization_id)
      |> Client.create_changeset()
    )
  end
end
