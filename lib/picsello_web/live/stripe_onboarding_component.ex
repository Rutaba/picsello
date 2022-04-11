defmodule PicselloWeb.StripeOnboardingComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.Payments

  require Logger

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> ok()
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> Enum.into(%{
        class: nil
      })

    ~H"""
    <div>
      <.form for={:stripe} phx-submit="link-stripe" phx-target={@myself}>
        <%= case @stripe_status do %>
          <% :loading -> %>
            <div class="flex items-center justify-center w-full m-2 text-xs">
              <div class="w-3 h-3 mr-2 rounded-full opacity-75 bg-blue-planning-300 animate-ping"></div>
              Loading...
            </div>

          <% :error -> %>
            <button type="submit" phx-disable-with="Retry Stripe account" class={@class}>
              Retry Stripe account
            </button>
            <em class={"block pt-1 text-xs text-red-sales-300 " <> @error_class}>Error accessing your Stripe information.</em>

          <% :no_account -> %>
            <button type="submit" phx-disable-with="Set up Stripe" class={@class}>
              Set up Stripe
            </button>

          <% :missing_information -> %>
            <button type="submit" phx-disable-with="Stripe Account incomplete" class={@class}>
              Stripe Account incomplete
            </button>
            <em class="block pt-1 text-xs text-center text-red-sales-300">Please provide missing information.</em>

          <% :pending_verification -> %>
            <button type="submit" phx-disable-with="Check Stripe status" class={@class}>
              Check Stripe status
            </button>
            <em class="block pt-1 text-xs text-center">Your account has been created. Please wait for Stripe to verify your information.</em>

          <% :charges_enabled -> %>
            <%= link to: URI.parse("https://dashboard.stripe.com/"), target: "_blank" do %>
              <button type="button" class={@class}>
                Go to Stripe Account
              </button>
            <% end %>

        <% end %>
      </.form>

    </div>
    """
  end

  @impl true
  def handle_event(
        "link-stripe",
        %{},
        %{assigns: %{current_user: current_user, return_url: return_url}} = socket
      ) do
    refresh_url = socket |> Routes.user_settings_url(:stripe_refresh)

    case Payments.link(current_user, refresh_url: refresh_url, return_url: return_url) do
      {:ok, url} ->
        socket |> redirect(external: url) |> noreply()

      {:error, error} ->
        Logger.error(error)
        socket |> put_flash(:error, "Couldn't link stripe account.") |> noreply()
    end
  end
end
