defmodule Picsello.Card do
  @moduledoc false
  use Ecto.Schema
  alias Picsello.{Repo}

  import Ecto.Changeset
  import Ecto.Query, only: [order_by: 2]

  defmodule Button do
    @moduledoc false
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field :class, :string
      field :label, :string
      field :external_link, :string
      field :action, :string
      field :link, :string
    end

    def changeset(button \\ %__MODULE__{}, attrs) do
      button
      |> cast(attrs, [:class, :label, :external_link, :action, :link])
    end
  end

  schema "cards" do
    field :concise_name, :string
    field :title, :string
    field :body, :string
    field :icon, :string
    field :color, :string
    field :class, :string
    field :index, :integer

    embeds_many :buttons, Button, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(campaign \\ %__MODULE__{}, attrs) do
    campaign
    |> cast(attrs, [:concise_name, :title, :body, :icon, :color, :class, :index])
    |> cast_embed(:buttons)
    |> validate_required([:concise_name, :title])
  end

  def list() do
    Picsello.Card
    |> order_by(desc: :index)
    |> Repo.all()
  end
end
