defmodule Picsello.StripePaymentsTest do
  use Picsello.DataCase, async: true

  describe "status" do
    test ":none when user has no stripe account" do
      user = insert(:user)
      assert {:ok, :none} == Picsello.StripePayments.status(user)
    end

    test ":processing when stripe account, but charges are not enabled" do
      user = insert(:user, %{stripe_account_id: "abc"})
      assert {:ok, :processing} == Picsello.StripePayments.status(user)
    end
  end

  describe "link" do
    test "returns a link" do
      {:ok, url} = Picsello.StripePayments.link(insert(:user), [])

      assert URI.parse(url).host |> String.contains?("stripe")
    end
  end
end
