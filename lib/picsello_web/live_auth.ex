defmodule PicselloWeb.LiveAuth do
  @moduledoc false
  import Phoenix.LiveView
  alias PicselloWeb.Router.Helpers, as: Routes
  alias Picsello.{Accounts, Accounts.User}
  alias Picsello.Galleries

  def on_mount(:default, _params, session, socket) do
    socket |> allow_sandbox() |> mount(session)
  end

  def on_mount(:gallery_client, %{"hash" => hash}, params, socket) do
    socket = allow_sandbox(socket)
    gallery = Galleries.get_gallery_by_hash(hash)

    socket
    |> assign(gallery: gallery)
    |> assign(
      authenticated:
        Galleries.session_exists_with_token?(gallery.id, params["gallery_session_token"])
    )
    |> cont()
  end

  defp mount(socket, %{"user_token" => user_token}) do
    socket
    |> assign_new(:current_user, fn ->
      Accounts.get_user_by_session_token(user_token)
    end)
    |> then(fn
      %{assigns: %{current_user: nil}} = socket ->
        socket |> redirect(to: Routes.user_session_path(socket, :new)) |> halt()

      socket ->
        maybe_redirect_to_onboarding(socket)
    end)
  end

  defp mount(socket, _session), do: socket |> halt()

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
