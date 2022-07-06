defmodule Picsello.SubscriptionPlansMetadata do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Picsello.{
    Repo
  }

  schema "subscription_plans_metadata" do
    field :code, :string
    field :trial_length, :integer
    field :active, :boolean
    field :signup_title, :string
    field :signup_description, :string
    field :onboarding_title, :string
    field :onboarding_description, :string
    field :success_title, :string

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

  def all_subscription_plans_metadata() do
    Repo.all(from(s in __MODULE__))
  end

  def subscription_plan_metadata(nil) do
    %Picsello.SubscriptionPlansMetadata{
      trial_length: 30,
      onboarding_description:
        "After 30 days, your subscription will be $20/month. (You can change to annual if you prefer in account settings.)",
      onboarding_title: "Start your 30-day free trial",
      signup_description:
        "Grow your photography business with Picsello—1 month free at signup and you secure the Founder Rate of $20 a month OR $200 a year",
      signup_title: "Let's get started!",
      success_title: "Your 30-day free trial has started!"
    }
  end

  def subscription_plan_metadata(code) do
    query = Repo.get_by(__MODULE__, code: code, active: true)

    if query === nil do
      subscription_plan_metadata(nil)
    else
      query
    end
  end

  def get_subscription_plan_metadata(code) do
    subscription_plan_metadata(code)
  end
end
