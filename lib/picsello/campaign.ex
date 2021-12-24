defmodule Picsello.Campaign do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias Picsello.{Organization, CampaignClient}

  @segment_types ~w[new all]

  schema "campaigns" do
    field(:subject, :string)
    field(:body_html, :string)
    field(:body_text, :string)
    field(:segment_type, :string)
    belongs_to(:organization, Organization)
    has_many(:campaign_clients, CampaignClient)
    has_many(:clients, through: [:campaign_clients, :client])

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(campaign \\ %__MODULE__{}, attrs) do
    campaign
    |> cast(attrs, [:subject, :body_text, :body_html, :organization_id, :segment_type])
    |> validate_inclusion(:segment_type, @segment_types)
    |> validate_required([:subject, :body_text, :body_html, :organization_id, :segment_type])
  end
end
