defmodule Picsello.JobTest do
  use Picsello.DataCase, async: true
  alias Picsello.{Client, Job, Organization, Package, Repo, Shoot}

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

  describe "padded_shoots" do
    setup %{organization_id: organization_id} do
      %{id: package_id} =
        Package.create_changeset(%{
          description: "a package",
          name: "a package",
          price: "200",
          shoot_count: 2,
          organization_id: organization_id
        })
        |> Repo.insert!()

      %{id: client_id} =
        Client.create_changeset(%{
          name: "Morty",
          email: "morty@example.com",
          organization_id: organization_id
        })
        |> Repo.insert!()

      [
        job:
          Job.create_changeset(%{type: "family", client_id: client_id})
          |> Job.add_package_changeset(%{package_id: package_id})
          |> Repo.insert!()
      ]
    end

    test "when there are fewer shoots than the package says it pads with nils", %{job: job} do
      assert [{1, nil}, {2, nil}] = job |> Job.padded_shoots()
    end

    test "when there are more shoots than the package says it returns the shoots", %{job: job} do
      %{id: shoot_id} =
        Shoot.create_changeset(%{
          duration_minutes: 15,
          location: "home",
          name: "chute",
          job_id: job.id,
          starts_at: DateTime.utc_now() |> DateTime.add(60 * 60 * 24, :second)
        })
        |> Repo.insert!()

      assert [{1, %Shoot{id: ^shoot_id}}, {2, nil}] = job |> Job.padded_shoots()
    end
  end
end
