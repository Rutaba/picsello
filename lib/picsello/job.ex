defmodule Picsello.Job do
  @moduledoc false
  @types ~w[wedding family new_born other]

  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias Picsello.{Client, Repo, Package}

  schema "jobs" do
    field(:type, :string)
    belongs_to(:client, Client)
    belongs_to(:package, Package)

    timestamps()
  end

  def types(), do: @types

  def create_changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, [:type, :client_id])
    |> cast_assoc(:client, with: &Client.create_changeset/2)
    |> validate_required([:type])
    |> validate_inclusion(:type, @types)
    |> assoc_constraint(:client)
  end

  def add_package_changeset(job \\ %__MODULE__{}, attrs) do
    job
    |> cast(attrs, [:package_id])
    |> validate_required([:package_id])
    |> assoc_constraint(:package)
  end

  def name(%__MODULE__{type: type} = job) do
    %{client: %{name: client_name}} = job |> Repo.preload(:client)
    [client_name, Phoenix.Naming.humanize(type)] |> Enum.join(" ")
  end

  def for_user(%Picsello.Accounts.User{organization_id: organization_id}) do
    from(job in __MODULE__,
      join: client in Client,
      on: client.id == job.client_id,
      where: client.organization_id == ^organization_id
    )
  end
end
