defmodule PicselloWeb.UserResetPasswordEditLive do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Accounts, Accounts.User}

  @impl true
  def mount(%{"token" => token}, session, socket) do
    case socket
         |> assign_defaults(session)
         |> assign_user(token) do
      %{assigns: %{user: user}} = socket when user != nil ->
        socket |> assign(changeset: Accounts.change_user_password(user))

      socket ->
        socket
        |> put_flash(:error, "Reset password link is invalid or it has expired.")
        |> push_redirect(to: Routes.user_reset_password_path(socket, :new))
    end
    |> ok()
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      socket.assigns.user
      |> User.password_changeset(params)
      |> Map.put(:action, :validate)

    socket |> assign(changeset: changeset) |> noreply()
  end

  @impl true
  def handle_event("submit", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> User.password_changeset(user_params)
      |> Map.put(:action, :validate)

    if changeset.valid? do
      {:ok, _} = Accounts.reset_user_password(socket.assigns.user, user_params)

      socket
      |> put_flash(:info, "Password reset successfully.")
      |> push_redirect(to: Routes.user_session_path(socket, :new))
    else
      socket
      |> assign(changeset: changeset)
    end
    |> noreply()
  end

  defp assign_user(socket, token) do
    socket |> assign(user: Accounts.get_user_by_reset_password_token(token))
  end
end
