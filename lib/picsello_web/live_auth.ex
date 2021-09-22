defmodule PicselloWeb.LiveAuth do
  @moduledoc false
  import Phoenix.LiveView
  alias PicselloWeb.Router.Helpers, as: Routes
  alias Picsello.{Accounts, Accounts.User}

  def mount(
        _params,
        %{"user_token" => "" <> _user_token},
        %{assigns: %{current_user: %User{}}} = socket
      ) do
    socket
    |> allow_sandbox()
    |> cont()
  end

  def mount(_params, %{"user_token" => user_token}, socket) do
    socket = socket |> allow_sandbox()

    case Accounts.get_user_by_session_token(user_token) do
      nil -> socket |> redirect(to: Routes.user_session_path(socket, :new)) |> halt()
      user -> socket |> assign(:current_user, user) |> maybe_redirect_to_onboarding()
    end
  end

  def mount(_params, _session, socket) do
    socket |> allow_sandbox() |> halt()
  end

  defp allow_sandbox(socket) do
    with sandbox when sandbox != nil <- Application.get_env(:picsello, :sandbox),
         true <- connected?(socket),
         metadata when is_binary(metadata) <- get_connect_info(socket)[:user_agent] do
      sandbox.allow(metadata, self())
    end

    socket
  end

  defp maybe_redirect_to_onboarding(
         %{view: view, assigns: %{current_user: current_user}} = socket
       ) do
    onboarding_view = PicselloWeb.OnboardingLive.Index

    case {view, User.onboarded?(current_user)} do
      {^onboarding_view, true} ->
        socket |> push_redirect(to: Routes.home_path(socket, :index)) |> halt()

      {_, true} ->
        socket |> cont()

      {^onboarding_view, false} ->
        socket |> cont()

      {_, false} ->
        socket |> push_redirect(to: Routes.onboarding_path(socket, :index)) |> halt()
    end
  end

  defp cont(socket), do: {:cont, socket}
  defp halt(socket), do: {:halt, socket}
end
