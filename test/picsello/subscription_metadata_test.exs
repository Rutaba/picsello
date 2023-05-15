defmodule Picsello.SubscriptionMetadataTest do
  use Picsello.DataCase, async: true
  alias Picsello.{Subscriptions}

  describe "usage of variable trial codes" do
    test "add subscription trial code" do
      random_code = generate_random_code()

      %Picsello.SubscriptionPlansMetadata{
        code: ^random_code,
        trial_length: 90,
        active: true,
        onboarding_title: "Start your 90-day free trial"
      } = insert_subscription_metadata_factory!(%{active: true, code: random_code})
    end

    test "get active subscription trial code" do
      random_code = generate_random_code()
      insert_subscription_metadata_factory!(%{active: true, code: random_code})

      %Picsello.SubscriptionPlansMetadata{
        code: ^random_code,
        trial_length: 90,
        active: true,
        onboarding_title: "Start your 90-day free trial"
      } = Subscriptions.get_subscription_plan_metadata(random_code)
    end

    test "get default subscription content when no trial codes" do
      %Picsello.SubscriptionPlansMetadata{
        code: nil,
        trial_length: 14,
        success_title: "Your 14-day free trial has started!"
      } = Subscriptions.get_subscription_plan_metadata("99999")

      %Picsello.SubscriptionPlansMetadata{
        code: nil,
        trial_length: 14,
        onboarding_title: "Start your 14-day free trial"
      } = Subscriptions.get_subscription_plan_metadata()
    end

    test "get default subscription content when trial code is inactive" do
      random_code = generate_random_code()
      insert_subscription_metadata_factory!(%{code: random_code})

      %Picsello.SubscriptionPlansMetadata{
        code: nil,
        trial_length: 14,
        success_title: "Your 14-day free trial has started!"
      } = Subscriptions.get_subscription_plan_metadata(random_code)
    end
  end
end
