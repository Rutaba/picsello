defmodule Picsello.JobTest do
  use Picsello.DataCase, async: true
  alias Picsello.{Client, Job, Organization, Repo}

  setup do
    %{id: organization_id} =
      Organization.registration_changeset(%{name: "Citadel"}) |> Repo.insert!()

    [organization_id: organization_id]
  end

  describe "create_changeset" do
    setup %{organization_id: organization_id} do
      client_attributes = %{
        name: "Morty",
        email: "morty@example.com",
        organization_id: organization_id
      }

      [client_attributes: client_attributes]
    end

    test "works with client_id", %{client_attributes: client_attributes} do
      %{id: client_id} =
        Client.create_changeset(client_attributes)
        |> Repo.insert!()

      Job.create_changeset(%{type: "family", client_id: client_id}) |> Repo.insert!()
    end

    test "error when wrong client_id" do
      assert {:error, changeset} =
               Job.create_changeset(%{type: "family", client_id: 9000})
               |> Repo.insert()

      assert {"does not exist", _} = changeset.errors[:client]
    end

    test "works with client attributes", %{client_attributes: client_attributes} do
      Job.create_changeset(%{type: "family", client: client_attributes}) |> Repo.insert!()
    end

    test "error when wrong client attributes" do
      assert {:error, changeset} =
               Job.create_changeset(%{type: "family", client: %{}})
               |> Repo.insert()

      refute changeset.changes[:client].errors |> Enum.empty?()
    end
  end
end
