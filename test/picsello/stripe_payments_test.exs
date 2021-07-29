defmodule Picsello.StripePaymentsTest do
  use Picsello.DataCase, async: true

  describe "status" do
    test ":none when organization has no stripe account" do
      organization = insert(:organization)
      assert {:ok, :none} == Picsello.StripePayments.status(organization)
    end

    test ":processing when stripe account, but charges are not enabled" do
      organization = insert(:organization, %{stripe_account_id: "abc"})
      assert {:ok, :processing} == Picsello.StripePayments.status(organization)
    end
  end

  describe "link" do
    test "returns a link" do
      {:ok, url} = Picsello.StripePayments.link(insert(:organization), [])

      assert URI.parse(url).host |> String.contains?("stripe")
    end
  end
end
