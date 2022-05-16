defmodule PicselloWeb.UserRegisterLive do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "onboarding"]

  alias Picsello.{Accounts, Accounts.User}
  import PicselloWeb.OnboardingLive.Index, only: [container: 1]

  @impl true
  def mount(_params, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign(%{
      page_title: "Sign up",
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
