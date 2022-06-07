defmodule Picsello.PaymentsTest do
  use Picsello.DataCase, async: true
  alias Picsello.Payments

  describe "status" do
    test ":no_account when organization has no stripe account" do
      organization = insert(:organization)
      assert :no_account == Payments.status(organization)
    end

    test ":missing_information when there is a disabled reason other than 'pending verification'" do
      account = %Stripe.Account{
        charges_enabled: false,
        requirements: %{
          disabled_reason: "requirements.past_due"
        }
      }

      assert :missing_information == Payments.account_status(account)
    end

    test ":pending_verification when the disabled reason is 'pending verification'" do
      account = %Stripe.Account{
        charges_enabled: false,
        requirements: %{
          disabled_reason: "requirements.pending_verification"
        }
      }

      assert :pending_verification == Payments.account_status(account)
    end

    test ":charges_enabled when charges are enabled (and disabled reason is nil)" do
      account = %Stripe.Account{
        charges_enabled: true
      }

      assert :charges_enabled == Payments.account_status(account)
    end
  end

  describe "link" do
    test "returns a link when called with a user with no account" do
      Picsello.MockPayments
      |> Mox.stub(:create_account, fn %{type: "standard"}, _ ->
        {:ok, %Stripe.Account{id: "new-account-id"}}
      end)
      |> Mox.stub(
        :create_account_link,
        fn %{type: "account_onboarding", account: "new-account-id"}, _ ->
          {:ok, %Stripe.AccountLink{url: "https://example.com/new-account-id"}}
        end
      )

      user = insert(:user)
      assert {:ok, url} = Payments.link(user, [])

      assert "/new-account-id" = url |> URI.parse() |> Map.get(:path)

      assert %{organization: %{stripe_account_id: "new-account-id"}} =
               user |> Repo.preload(:organization, force: true)
    end

    test "returns a link when called with a user with an account" do
      user =
        insert(:user,
          organization: insert(:organization, stripe_account_id: "already-saved-stub-account-id")
        )

      Mox.stub(Picsello.MockPayments, :create_account_link, fn %{
                                                                 account:
                                                                   "already-saved-stub-account-id",
                                                                 type: "account_onboarding"
                                                               },
                                                               _ ->
        {:ok, %{url: "https://example.com/already-saved-stub-account-id"}}
      end)

      assert {:ok, url} = Payments.link(user, [])

      assert "/already-saved-stub-account-id" = url |> URI.parse() |> Map.get(:path)
    end
  end

  describe "create_session" do
    test "returns url when 1st attempt with automatic tax enabled succeeds" do
      Picsello.MockPayments
      |> Mox.expect(:create_session, 1, fn params, opts ->
        assert %{
                 automatic_tax: %{enabled: true},
                 mode: "payment",
                 payment_method_types: ["card"],
                 success_url: "<URL>"
               } == params

        assert [connect_account: "123"] = opts
        {:ok, %Stripe.Session{url: "<NEW_URL>"}}
      end)

      assert {:ok, %{url: "<NEW_URL>"}} =
               Payments.create_session(%{success_url: "<URL>"}, connect_account: "123")
    end

    test "returns url when 2nd attempt with automatic tax disabled succeeds" do
      Picsello.MockPayments
      |> Mox.expect(:create_session, 1, fn params, opts ->
        assert %{
                 automatic_tax: %{enabled: true},
                 mode: "payment",
                 payment_method_types: ["card"],
                 success_url: "<URL>"
               } == params

        assert [connect_account: "123"] = opts
        {:error, "ERROR"}
      end)
      |> Mox.expect(:create_session, 1, fn params, opts ->
        assert %{
                 mode: "payment",
                 payment_method_types: ["card"],
                 success_url: "<URL>"
               } == params

        assert [connect_account: "123"] = opts
        {:ok, %Stripe.Session{url: "<NEW_URL>"}}
      end)

      assert {:ok, %{url: "<NEW_URL>"}} =
               Payments.create_session(%{success_url: "<URL>"}, connect_account: "123")
    end

    test "returns error when 2nd attempt with automatic tax disabled fails" do
      Picsello.MockPayments
      |> Mox.expect(:create_session, 1, fn params, opts ->
        assert %{
                 automatic_tax: %{enabled: true},
                 mode: "payment",
                 payment_method_types: ["card"],
                 success_url: "<URL>"
               } == params

        assert [connect_account: "123"] = opts
        {:error, "error"}
      end)
      |> Mox.expect(:create_session, 1, fn params, opts ->
        assert %{
                 mode: "payment",
                 payment_method_types: ["card"],
                 success_url: "<URL>"
               } == params

        assert [connect_account: "123"] = opts
        {:error, "ERROR"}
      end)

      assert {:error, "ERROR"} =
               Payments.create_session(%{success_url: "<URL>"}, connect_account: "123")
    end
  end
end
