defmodule Picsello.PaymentsTest do
  use Picsello.DataCase, async: true

  describe "status" do
    test "nil when user has no stripe account" do
      user = insert(:user)
      assert {:ok, nil} == Picsello.Payments.status(user)
    end

    test ":processing when stripe account, but charges are not enabled" do
      user = insert(:user, %{stripe_account_id: "abc"})
      assert {:ok, :processing} == Picsello.Payments.status(user)
    end
  end

  describe "link" do
    test "returns a link" do
      {:ok, url} = Picsello.Payments.link(insert(:user), [])

      assert URI.parse(url).host |> String.contains?("stripe")
    end
  end
end
