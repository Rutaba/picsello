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

  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_password_change()
    |> ok()
  end

  def handle_event("change", %{"login" => params}, socket) do
    socket
    |> assign_password_change(params)
    |> noreply()
  end

  def handle_event(
        "check",
        %{"login" => %{"email" => email, "password" => password}},
        %{assigns: %{gallery: gallery}} = socket
      ) do
    valid_email? = String.length(email) > 0 && Regex.match?(~r/^[^\s]+@[^\s]+.[^\s]+$/, email)

    if valid_email? do
      gallery
      |> Galleries.build_gallery_session_token(password, email)
      |> case do
        {:ok, token} ->
          update_emails_map(email, gallery)
          assign(socket, submit: true, session_token: token)

        _ ->
          assign(socket, password_is_correct: false)
      end
    else
      assign(socket, password_is_correct: false, submit: false)
    end
    |> noreply()
  end

  defp assign_password_change(socket, params \\ %{}) do
    params
    |> Galleries.gallery_password_change()
    |> then(&assign(socket, :password_changeset, &1))
  end

  defp update_emails_map(email, gallery) do
    new_email_map = %{
      "email" => email,
      "viewed_at" => DateTime.utc_now()
    }

    email_list = gallery.gallery_analytics || []
    updated_email_list = email_list ++ [new_email_map]

    Galleries.update_gallery(gallery, %{gallery_analytics: updated_email_list})
  end
end
