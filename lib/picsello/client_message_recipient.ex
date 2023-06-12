defmodule Picsello.ClientMessageRecipient do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Picsello.{Client, ClientMessage}

  schema "client_message_recipients" do
    belongs_to(:client, Client)
    belongs_to(:client_message, ClientMessage)
    field(:recipient_type, Ecto.Enum, values: [:to, :cc, :bcc, :from])

    timestamps(type: :utc_datetime)
  end

  @attrs [:client_id, :client_message_id, :recipient_type]
  @doc false
  def changeset(client_message_recipient \\ %__MODULE__{}, attrs) do
    client_message_recipient
    |> cast(attrs, @attrs)
    |> validate_required(@attrs)
    |> assoc_constraint(:client)
    |> assoc_constraint(:client_message)
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @attrs)
    |> validate_required(@attrs)
  end
end
