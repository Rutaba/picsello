defmodule PicselloWeb.UserRegisterLive do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "onboarding"]

  alias Picsello.{Accounts, Accounts.User}
  import PicselloWeb.OnboardingLive.Index, only: [container: 1]
  import Picsello.Subscriptions, only: [get_subscription_plan: 1, subscription_content: 1]

  @impl true
  def mount(_params, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign(%{
      subscription_plan_month: get_subscription_plan("month"),
      subscription_plan_year: get_subscription_plan("year")
    })
    |> assign(%{
      page_title: "Sign Up",
      meta_attrs: %{
        description:
          "Let's get started! Get signed up and start growing your business. Register with Picsello and start managing, marketing, and monetizing your photography business today."
      }
    })
    |> assign_changeset()
    |> assign_trigger_submit()
    |> ok()
  end

  @impl true
  def handle_event("validate", %{"user" => %{"trigger_submit" => "true"}}, socket) do
    socket |> noreply()
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    socket |> assign_changeset(params, :validate) |> noreply()
  end

  @impl true
  def handle_event("previous", %{}, socket) do
    socket |> noreply()
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    socket
    |> assign_changeset(user_params, :validate)
    |> assign_trigger_submit()
    |> noreply()
  end

  defp assign_trigger_submit(%{assigns: %{changeset: changeset}} = socket) do
    socket |> assign(trigger_submit: changeset.valid?)
  end

  defp assign_changeset(socket, params \\ %{}, action \\ nil) do
    socket
    |> assign(
      changeset: Accounts.change_user_registration(%User{}, params) |> Map.put(:action, action)
    )
  end
end
