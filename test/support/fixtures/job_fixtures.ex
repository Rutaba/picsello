defmodule Picsello.JobFixtures do
  @moduledoc """
  test helpers for creating job entities
  """
  alias Picsello.{Shoot, AccountsFixtures, Client, Job, Package, Repo, Organization}

  def fixture(struct, %{} = attrs \\ %{}) when is_atom(struct),
    do: apply(__MODULE__, :"#{struct}_fixture", [attrs])

  def organization_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(AccountsFixtures.valid_organization_attributes())
    |> Organization.registration_changeset()
    |> Repo.insert!()
  end

  def package_fixture(attrs \\ %{})

  def package_fixture(%{organization: %{} = organization_attrs} = attrs) do
    attrs
    |> Map.drop([:organization])
    |> Enum.into(%{organization_id: organization_fixture(organization_attrs).id})
    |> package_fixture()
  end

  def package_fixture(%{user: user} = attrs) do
    attrs
    |> Map.drop([:user])
    |> Map.put(:organization_id, user.organization_id)
    |> package_fixture()
  end

  def package_fixture(%{} = attrs) do
    attrs
    |> Enum.into(%{
      price: 10,
      name: "Package name",
      description: "Package description",
      shoot_count: 2
    })
    |> Package.create_changeset()
    |> Repo.insert!()
  end

  def client_fixture(attrs \\ %{})

  def client_fixture(%{organization: organization_attrs} = attrs) do
    attrs
    |> Map.drop([:organization])
    |> Map.put(:organization_id, organization_fixture(organization_attrs).id)
    |> client_fixture()
  end

  def client_fixture(%{user: user} = attrs) do
    attrs
    |> Map.drop([:user])
    |> Map.put(:organization_id, user.organization_id)
    |> client_fixture()
  end

  def client_fixture(%{} = attrs) do
    attrs
    |> Enum.into(%{
      email: "client#{System.unique_integer()}@example.com",
      name: "Mary Jane"
    })
    |> Client.create_changeset()
    |> Repo.insert!()
  end

  def shoot_fixture(attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      duration_minutes: 15,
      location: "home",
      name: "chute",
      starts_at: DateTime.utc_now()
    })
    |> Shoot.create_changeset()
    |> Repo.insert!()
  end

  def job_fixture(attrs \\ %{})

  def job_fixture(%{package: %{} = package_attrs, user: user} = attrs) do
    package =
      package_attrs |> Enum.into(%{organization_id: user.organization_id}) |> package_fixture()

    attrs |> Map.drop([:package]) |> Enum.into(%{package_id: package.id}) |> job_fixture()
  end

  def job_fixture(%{client: %{} = client_attrs, user: user} = attrs) do
    client =
      client_attrs |> Enum.into(%{organization_id: user.organization_id}) |> client_fixture()

    attrs |> Map.drop([:client, :user]) |> Enum.into(%{client_id: client.id}) |> job_fixture()
  end

  def job_fixture(%{user: _} = attrs) do
    attrs
    |> Map.put(:client, %{})
    |> job_fixture()
  end

  def job_fixture(%{} = attrs) do
    case attrs |> Enum.into(%{type: "wedding"}) do
      %{package_id: _} = attrs ->
        attrs
        |> Map.drop([:package_id])
        |> Job.create_changeset()
        |> Job.add_package_changeset(attrs |> Map.take([:package_id]))

      attrs ->
        attrs |> Job.create_changeset()
    end
    |> Repo.insert!()
  end
end
