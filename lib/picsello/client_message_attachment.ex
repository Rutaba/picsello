defmodule Picsello.ClientMessageAttachment do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Picsello.{ClientMessage, Campaign}

  schema "client_message_attachments" do
    field(:name, :string)
    field(:url, :string)
    belongs_to(:client_message, ClientMessage)
    belongs_to(:campaign, Campaign)

    timestamps(type: :utc_datetime)
  end

  @attrs [:client_message_id, :name, :url, :campaign_id]
  @conditonal_required_fields [:client_message_id, :campaign_id]
  @doc false
  def changeset(client_message_attachment \\ %__MODULE__{}, attrs) do
    client_message_attachment
    |> cast(attrs, @attrs)
    |> validate_required([:name, :url])
    |> then(fn changeset ->
      if Enum.any?(@conditonal_required_fields, &get_field(changeset, &1)) do
        changeset
      else
        add_error(changeset, :campaign, "campaign_id or client_message_id required")
      end
    end)
    |> assoc_constraint(:client_message)
    |> assoc_constraint(:campaign)
  end
end
