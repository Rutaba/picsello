defmodule PicselloWeb.LiveAuth do
  @moduledoc false
  import Phoenix.LiveView
  alias PicselloWeb.Router.Helpers, as: Routes
  alias Picsello.{Accounts, Accounts.User, Subscriptions}
  alias Picsello.Galleries

  def on_mount(:default, _params, session, socket) do
    socket |> allow_sandbox() |> mount(session)
  end

  def on_mount(:gallery_client, params, session, socket) do
    socket
    |> allow_sandbox()
    |> authenticate_gallery(params)
    |> authenticate_gallery_expiry()
    |> authenticate_gallery_client(session)
    |> authenticate_gallery_for_photographer(session)
    |> maybe_redirect_to_client_login(params)
  end

  def on_mount(:gallery_client_login, params, _session, socket) do
    socket
    |> allow_sandbox()
    |> authenticate_gallery(params)
    |> cont()
  end

  defp mount(socket, %{"user_token" => _user_token} = session) do
    socket
    |> assign_current_user(session)
    |> then(fn
      %{assigns: %{current_user: nil}} = socket ->
        socket |> redirect(to: Routes.user_session_path(socket, :new)) |> halt()

      socket ->
        maybe_redirect_to_onboarding(socket)
    end)
  end

  defp mount(socket, _session), do: socket |> halt()

  defp assign_current_user(socket, %{"user_token" => user_token}) do
    socket
    |> assign_new(:current_user, fn ->
      Accounts.get_user_by_session_token(user_token)
    end)
  end

  defp assign_current_user(socket, _session), do: socket

  defp authenticate_gallery(socket, %{"hash" => hash}) do
    socket
    |> assign_new(:gallery, fn ->
      Galleries.get_gallery_by_hash!(hash) |> Galleries.populate_organization_user()
    end)
  end

  defp authenticate_gallery_expiry(%{assigns: %{gallery: gallery}} = socket) do
    subscription_expired =
      gallery |> Galleries.gallery_photographer() |> Subscriptions.subscription_expired?()

    if Galleries.expired?(gallery) || subscription_expired do
      socket
      |> push_redirect(
        to:
          Routes.gallery_client_show_gallery_expire_path(
            socket,
            :show,
            gallery.client_link_hash
          )
      )
      |> halt()
    else
      socket
    end
  end

  defp authenticate_gallery_client(%{assigns: %{gallery: gallery}} = socket, session) do
    socket
    |> assign(
      authenticated:
        Galleries.session_exists_with_token?(
          gallery.id,
          Map.get(session, "gallery_session_token")
        )
    )
  end

  defp authenticate_gallery_client(socket, _), do: socket

  defp allow_sandbox(socket) do
    with sandbox when sandbox != nil <- Application.get_env(:picsello, :sandbox),
         true <- connected?(socket),
         metadata when is_binary(metadata) <- get_connect_info(socket, :user_agent) do
      sandbox.allow(metadata, self())
    end

    socket
  end

  defp maybe_redirect_to_client_login(socket, %{"hash" => hash}) do
    with %{assigns: %{authenticated: authenticated}} <- socket,
         false <- authenticated do
      socket
      |> push_redirect(to: Routes.gallery_client_show_login_path(socket, :login, hash))
      |> halt()
    else
      true ->
        socket |> cont()

      _ ->
        socket
    end
  end

  defp maybe_redirect_to_onboarding(
         %{view: view, assigns: %{current_user: current_user}} = socket
       ) do
    onboarding_view = PicselloWeb.OnboardingLive.Index

    case {view, User.onboarded?(current_user)} do
      {^onboarding_view, true} ->
        socket |> push_redirect(to: Routes.home_path(socket, :index)) |> halt()

      {_, true} ->
        socket |> maybe_redirect_to_home()

      {^onboarding_view, false} ->
        socket |> cont()

      {_, false} ->
        socket |> push_redirect(to: Routes.onboarding_path(socket, :index)) |> halt()
    end
  end

  defp maybe_redirect_to_home(%{view: view, assigns: %{current_user: current_user}} = socket) do
    views = [PicselloWeb.LiveModal, PicselloWeb.HomeLive.Index]

    if !Enum.member?(views, view) && Subscriptions.subscription_expired?(current_user) do
      socket |> push_redirect(to: Routes.home_path(socket, :index)) |> halt()
    else
      socket |> cont()
    end
  end

  defp authenticate_gallery_for_photographer(%{assigns: %{gallery: gallery}} = socket, session) do
    socket
    |> assign_current_user(session)
    |> then(fn
      %{assigns: %{current_user: current_user}} = socket ->
        socket
        |> assign(authenticated: current_user.id == Galleries.gallery_photographer(gallery).id)

      socket ->
        socket
    end)
  end

  defp authenticate_gallery_for_photographer(socket, _), do: socket

  defp cont(socket), do: {:cont, socket}
  defp halt(socket), do: {:halt, socket}
end
