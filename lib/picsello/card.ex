defmodule Picsello.Card do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "cards" do
    field :concise_name, :string
    field :title, :string
    field :body, :string
    field :icon, :string
    field :color, :string
    field :class, :string
    field :index, :integer

    embeds_many :buttons, Button do
      field :class, :string
      field :label, :string
      field :external_link, :string
      field :action, :string
      field :link, :string
    end

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(campaign \\ %__MODULE__{}, attrs) do
    campaign
    |> cast(attrs, [:concise_name, :title, :body, :icon, :color, :class, :buttons])
    |> validate_required([:concise_name, :title])
  end
end
