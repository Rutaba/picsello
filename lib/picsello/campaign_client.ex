defmodule Picsello.CampaignClient do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "campaign_clients" do
    belongs_to(:client, Picsello.Client)
    belongs_to(:campaign, Picsello.Campaign)
    field(:delivered_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(campaign_client, attrs) do
    campaign_client
    |> cast(attrs, [:client_id, :campaign_id])
    |> validate_required([:client_id, :campaign_id])
  end
end
