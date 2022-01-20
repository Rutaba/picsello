defmodule Picsello.StripePaymentsTest do
  use Picsello.DataCase, async: true

  defmodule StripeStub do
    defmodule Account do
      def create(%{type: "standard"}) do
        {:ok, %{id: "new-account-id"}}
      end
    end

    defmodule AccountLink do
      def create(%{account: account, type: "account_onboarding"}) do
        {:ok, %{url: "https://example.com/#{account}"}}
      end
    end
  end

  def link(user_or_organization, opts) do
    Picsello.StripePayments.link(user_or_organization, opts, StripeStub)
  end

  describe "status" do
    test ":no_account when organization has no stripe account" do
      organization = insert(:organization)
      assert :no_account == Picsello.StripePayments.status(organization)
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
    test "returns a link when called with a user with no account" do
      user = insert(:user)
      assert {:ok, url} = link(user, [])

      assert "/new-account-id" = url |> URI.parse() |> Map.get(:path)

      assert %{organization: %{stripe_account_id: "new-account-id"}} =
               user |> Repo.preload(:organization, force: true)
    end

    test "returns a link when called with a user with an account" do
      user =
        insert(:user,
          organization: insert(:organization, stripe_account_id: "already-saved-stub-account-id")
        )

      assert {:ok, url} = link(user, [])

      assert "/already-saved-stub-account-id" = url |> URI.parse() |> Map.get(:path)
    end
  end

  describe "cart checkout params" do
    test "returns correct line items" do
      gallery = insert(:gallery)
      whcc_product = insert(:product)

      cart_product = build(:ordered_cart_product, %{product_id: whcc_product.whcc_id})

      %{products: products, shipping_cost: shipping_cost, subtotal_cost: subtotal_cost} =
        Picsello.Cart.place_product(cart_product, gallery.id)

      checkout_params =
        Picsello.StripePayments.cart_checkout_params(products, shipping_cost,
          success_url: "https://example.com/success",
          cancel_url: "https://example.com/error"
        )

      assert [
               %{
                 price_data: %{
                   currency: :USD,
                   product_data: %{
                     images: [cart_product.editor_details.preview_url],
                     name:
                       cart_product.editor_details.selections["size"] <>
                         " " <> whcc_product.whcc_name
                   },
                   unit_amount: subtotal_cost.amount
                 },
                 quantity: cart_product.editor_details.selections["quantity"]
               }
             ] == checkout_params.line_items
    end
  end
end
