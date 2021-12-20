defmodule Picsello.CampaignClient do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "campaign_clients" do
    field(:client_id, :id)
    field(:campaign_id, :id)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(campaign_client, attrs) do
    campaign_client
    |> cast(attrs, [:client_id, :campaign_id])
    |> validate_required([:client_id, :campaign_id])
  end
end
