defmodule Picsello.Campaign do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Organization, CampaignClient, ClientMessageAttachment}

  @segment_types ~w[new all client_reply user_reply]

  schema "campaigns" do
    field(:subject, :string)
    field(:body_html, :string)
    field(:body_text, :string)
    field(:segment_type, :string)
    field(:read_at, :utc_datetime)
    field(:deleted_at, :utc_datetime)
    belongs_to(:organization, Organization)
    belongs_to(:parent, __MODULE__)
    has_many(:campaign_clients, CampaignClient)
    has_many(:campaign_replies, __MODULE__, references: :id, foreign_key: :parent_id)
    has_many(:clients, through: [:campaign_clients, :client])
    has_many(:client_message_attachments, ClientMessageAttachment)

    timestamps(type: :utc_datetime)
  end

  @fields [:subject, :body_text, :body_html, :organization_id, :segment_type, :parent_id]
  @doc false
  def changeset(campaign \\ %__MODULE__{}, attrs) do
    campaign
    |> cast(attrs, @fields)
    |> validate_inclusion(:segment_type, @segment_types)
    |> validate_required(@fields -- [:parent_id])
  end

  def outbound_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, @fields)
    |> put_change(:read_at, DateTime.utc_now() |> DateTime.truncate(:second))
    |> put_change(:segment_type, "user_reply")
    |> validate_required(@fields -- [:parent_id])
  end
end
