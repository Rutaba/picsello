defmodule PicselloWeb.GalleryLive.ClientShow.AuthenticationComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Galleries, Albums}

  def mount(socket) do
    socket
    |> assign(:password_is_correct, true)
    |> assign(:submit, false)
    |> assign(:session_token, nil)
    |> ok()
  end

  def update(%{live_action: live_action} = assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_password_change(live_action)
    |> ok()
  end

  def handle_event("change", %{"login" => params}, %{assigns: assigns} = socket) do
    socket
    |> assign_password_change(assigns.live_action, params)
    |> noreply()
  end

  def handle_event("check", %{"login" => %{"password" => password}}, socket) do
    socket.assigns
    |> build_session_token(password)
    |> case do
      {:ok, token} ->
        assign(socket, submit: true, session_token: token)

      _ ->
        assign(socket, password_is_correct: false)
    end
    |> noreply()
  end

  defp assign_password_change(socket, live_action, params \\ %{})

  defp assign_password_change(socket, :gallery_login, params) do
    params
    |> Galleries.gallery_password_change()
    |> then(&assign(socket, :password_changeset, &1))
  end

  defp assign_password_change(socket, :album_login, params) do
    params
    |> Albums.album_password_change()
    |> then(&assign(socket, :password_changeset, &1))
  end

  defp build_session_token(%{live_action: :gallery_login, gallery: gallery}, password) do
    Galleries.build_gallery_session_token(gallery, password)
  end

  defp build_session_token(%{live_action: :album_login, album: album}, password) do
    Galleries.build_album_session_token(album, password)
  end

  defp build_login_link(%{live_action: :gallery_login, socket: socket, gallery: gallery}) do
    Routes.gallery_session_path(socket, :gallery_login, gallery.client_link_hash)
  end

  defp build_login_link(%{live_action: :album_login, socket: socket, album: album}) do
    Routes.gallery_session_path(socket, :album_login, album.client_link_hash)
  end
end
