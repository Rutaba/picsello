defmodule PicselloWeb.StripeOnboardingLiveTest do
  use PicselloWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "when user has no stripe account" do
    test "it renders a button", %{conn: conn} do
      Mox.stub(Picsello.MockPayments, :status, fn _ ->
        {:ok, :none}
      end)

      {:ok, view, html} =
        conn
        |> live_isolated(PicselloWeb.StripeOnboardingLive,
          session: %{"return_url" => "https://google.com"}
        )

      assert html |> Floki.text() =~ "Loading..."

      assert [] = html |> Floki.find("button")

      assert view |> render() |> Floki.text() =~ "You must create a Stripe account"

      assert view |> render() |> Floki.find("button") |> Floki.text() =~ "Create Stripe Account"
    end
  end

  describe "when user clicks the button" do
    test "it disables the button", %{conn: conn} do
      Mox.stub(Picsello.MockPayments, :status, fn _ ->
        {:ok, :none}
      end)

      Mox.stub(Picsello.MockPayments, :link, fn _, _ ->
        {:ok, "https://stripe.com"}
      end)

      {:ok, view, _html} =
        conn
        |> live_isolated(PicselloWeb.StripeOnboardingLive,
          session: %{"return_url" => "https://google.com"}
        )

      html = view |> element("button") |> render_click()

      assert html |> Floki.text() =~ "You must create a Stripe account"

      assert ["disabled"] = html |> Floki.attribute("button", "disabled")

      assert_redirected(view, "https://stripe.com")
    end
  end

  describe "when user has stripe account" do
    test "it does not render a button", %{conn: conn} do
      Mox.stub(Picsello.MockPayments, :status, fn _ ->
        {:ok, :charges_enabled}
      end)

      {:ok, view, _html} =
        conn
        |> live_isolated(PicselloWeb.StripeOnboardingLive,
          session: %{"return_url" => "https://google.com"}
        )

      assert view |> render() |> Floki.text() =~ "50% deposit"

      assert [] = view |> render() |> Floki.find("button")
    end
  end
end
