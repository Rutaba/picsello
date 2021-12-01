defmodule PicselloWeb.GalleryLive.ClientShow.Login do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Galleries

  def update(%{gallery: gallery}, socket) do
    {:ok,
     socket
     |> assign(:gallery, gallery)
     |> assign(:password_is_correct, true)
     |> assign(:submit, false)
     |> assign(:session_changeset, Galleries.client_session_change_for_gallery(gallery, %{}))}
  end

  def handle_event(
        "check",
        %{"client_session" => %{"password" => password}},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    session_changeset =
      Galleries.client_session_change_for_gallery(gallery, %{password: password})

    socket
    |> assign(:session_changeset, session_changeset)
    |> assign(:password_is_correct, session_changeset.valid?)
    |> assign(:submit, session_changeset.valid?)
    |> noreply()
  end
end
