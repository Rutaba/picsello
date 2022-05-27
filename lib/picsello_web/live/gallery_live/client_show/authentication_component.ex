defmodule PicselloWeb.GalleryLive.ClientShow.AuthenticationComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Galleries

  def mount(socket) do
    socket
    |> assign(:password_is_correct, true)
    |> assign(:submit, false)
    |> assign(:session_token, nil)
    |> assign(:password_changeset, Galleries.gallery_password_change())
    |> ok()
  end

  def handle_event("change", %{"login" => params}, socket) do
    socket
    |> assign(:password_changeset, Galleries.gallery_password_change(params))
    |> noreply()
  end

  def handle_event(
        "check",
        %{"login" => %{"password" => password}},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    case Galleries.build_gallery_session_token(gallery, password) do
      {:ok, token} ->
        socket |> assign(submit: true, session_token: token)

      _ ->
        socket
        |> assign(password_is_correct: false)
    end
    |> noreply()
  end
end
