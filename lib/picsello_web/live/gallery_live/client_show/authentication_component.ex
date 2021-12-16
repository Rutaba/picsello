defmodule PicselloWeb.GalleryLive.ClientShow.AuthenticationComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Galleries

  def mount(socket) do
    socket
    |> assign(:password_is_correct, true)
    |> assign(:submit, false)
    |> assign(:session_token, nil)
    |> ok()
  end

  def handle_event(
        "check",
        %{"login" => %{"password" => password}},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    if gallery.password == password do
      {:ok, token} = Galleries.build_gallery_session_token(gallery)

      socket
      |> assign(:submit, true)
      |> assign(:session_token, token.token)
      |> noreply()
    else
      socket
      |> assign(:password_is_correct, false)
      |> noreply()
    end
  end
end
