defmodule Picsello.SubscriptionPlansMetadata do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Picsello.{
    Repo
  }

  defmodule Content do
    @moduledoc false
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field :signup_title, :string
      field :signup_description, :string
      field :onboarding_title, :string
      field :onboarding_description, :string
      field :success_title, :string
    end
  end

  schema "subscription_plans_metadata" do
    field :code, :string
    field :trial_length, :integer
    field :active, :boolean
    embeds_one :content, Content, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(subscription_plan_metadata \\ %__MODULE__{}, attrs) do
    subscription_plan_metadata
    |> cast(attrs, [:code, :trial_length, :active])
    |> cast_embed(:content, with: &content_changeset/2)
    |> validate_required([:code, :trial_length])
  end

  def content_changeset(schema, attrs) do
    schema
    |> cast(attrs, [
      :signup_title,
      :signup_description,
      :onboarding_title,
      :onboarding_description,
      :success_title
    ])
    |> validate_required([
      :signup_title,
      :signup_description,
      :onboarding_title,
      :onboarding_description,
      :success_title
    ])
  end

  def all_subscription_plans_metadata() do
    Repo.all(from(s in __MODULE__))
  end
end
