defmodule Picsello.SubscriptionPlansMetadata do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "subscription_plans_metadata" do
    field(:code, :string)
    field(:trial_length, :integer)
    field(:active, :boolean)
    field(:signup_title, :string)
    field(:signup_description, :string)
    field(:onboarding_title, :string)
    field(:onboarding_description, :string)
    field(:success_title, :string)

    timestamps()
  end

  @doc false
  def changeset(subscription_plan_metadata \\ %__MODULE__{}, attrs) do
    subscription_plan_metadata
    |> cast(attrs, [
      :code,
      :trial_length,
      :active,
      :signup_title,
      :signup_description,
      :onboarding_title,
      :onboarding_description,
      :success_title
    ])
    |> validate_required([
      :code,
      :trial_length,
      :signup_title,
      :signup_description,
      :onboarding_title,
      :onboarding_description,
      :success_title
    ])
  end
end
