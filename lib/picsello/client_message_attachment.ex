defmodule Picsello.ClientMessageAttachment do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Picsello.{ClientMessage}

  schema "client_message_attachments" do
    field(:name, :string)
    field(:url, :string)
    belongs_to(:client_message, ClientMessage)

    timestamps(type: :utc_datetime)
  end

  @attrs [:client_message_id, :name, :url]
  @doc false
  def changeset(client_message_attachment \\ %__MODULE__{}, attrs) do
    client_message_attachment
    |> cast(attrs, @attrs)
    |> validate_required(@attrs)
    |> assoc_constraint(:client_message)
  end
end
