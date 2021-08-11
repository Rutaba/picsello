defmodule Picsello.StripePaymentsTest do
  use Picsello.DataCase, async: true

  describe "status" do
    test ":no_account when organization has no stripe account" do
      organization = insert(:organization)
      assert {:ok, :no_account} == Picsello.StripePayments.status(organization)
    end

    test ":missing_information when there is a disabled reason other than 'pending verification'" do
      account = %Stripe.Account{
        charges_enabled: false,
        requirements: %{
          disabled_reason: "requirements.past_due"
        }
      }

      assert :missing_information == Picsello.StripePayments.account_status(account)
    end

    test ":pending_verification when the disabled reason is 'pending verification'" do
      account = %Stripe.Account{
        charges_enabled: false,
        requirements: %{
          disabled_reason: "requirements.pending_verification"
        }
      }

      assert :pending_verification == Picsello.StripePayments.account_status(account)
    end

    test ":charges_enabled when charges are enabled (and disabled reason is nil)" do
      account = %Stripe.Account{
        charges_enabled: true
      }

      assert :charges_enabled == Picsello.StripePayments.account_status(account)
    end
  end

  describe "link" do
    test "returns a link" do
      {:ok, url} = Picsello.StripePayments.link(insert(:organization), [])

      assert URI.parse(url).host |> String.contains?("stripe")
    end
  end
end
