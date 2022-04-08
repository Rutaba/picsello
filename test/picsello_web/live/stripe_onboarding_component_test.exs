defmodule PicselloWeb.StripeOnboardingComponentTest do
  use PicselloWeb.ConnCase
  import Phoenix.LiveViewTest

  def initial_render(status) do
    render_component(PicselloWeb.StripeOnboardingComponent,
      error_class: "text-center",
      id: :stripe_onboarding,
      current_user: insert(:user),
      stripe_status: status,
      return_url: "https://google.com"
    )
  end

  describe "with different stripe statuses" do
    test ":loading" do
      html = initial_render(:loading)
      button = html |> Floki.find("button")

      assert html |> Floki.text() =~ "Loading..."
      assert [] = button
    end

    test ":error" do
      html = initial_render(:error)
      button = html |> Floki.find("button")

      assert button |> Floki.text() =~ "Retry Stripe Account"
      assert [] = button |> Floki.attribute("disabled")
      assert html |> Floki.text() =~ "Error accessing your Stripe information"
    end

    test ":no_account" do
      html = initial_render(:no_account)
      button = html |> Floki.find("button")

      assert button |> Floki.text() =~ "Set up Stripe"
      assert [] = button |> Floki.attribute("disabled")
    end

    test ":missing_information" do
      html = initial_render(:missing_information)
      button = html |> Floki.find("button")

      assert button |> Floki.text() =~ "Stripe Account Incomplete"
      assert [] = button |> Floki.attribute("disabled")
      assert html |> Floki.text() =~ "Please provide missing information"
    end

    test ":pending_verification" do
      html = initial_render(:pending_verification)
      button = html |> Floki.find("button")

      assert button |> Floki.text() =~ "Check Stripe Status"
      assert [] = button |> Floki.attribute("disabled")
      assert html |> Floki.text() =~ "Please wait for Stripe to verify"
    end

    test ":charges_enabled" do
      html = initial_render(:charges_enabled)
      button = html |> Floki.find("button")

      assert button |> Floki.text() =~ "Go to Stripe Account"
    end
  end
end
