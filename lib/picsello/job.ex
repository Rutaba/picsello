defmodule Picsello.Job do
  @moduledoc false
  @types ~w[wedding family new_born other]

  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias Picsello.{Client, Repo}

  schema "jobs" do
    field :type, :string
    belongs_to(:client, Client)

    timestamps()
  end

  def types(), do: @types

  def create_changeset(attrs \\ %{}) do
    %__MODULE__{}
    |> cast(attrs, [:type])
    |> cast_assoc(:client, with: &Client.create_changeset/2)
    |> validate_required([:type, :client])
    |> validate_inclusion(:type, @types)
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
