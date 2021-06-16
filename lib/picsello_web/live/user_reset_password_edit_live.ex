defmodule PicselloWeb.UserResetPasswordEditLive do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Accounts, Accounts.User}

  @impl true
  def mount(%{"token" => token}, session, socket) do
    user = Accounts.get_user_by_reset_password_token(token)

    if user do
      socket
      |> assign(:user, user)
      |> assign(:changeset, Accounts.change_user_password(user))
    else
      socket
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> push_redirect(to: Routes.user_reset_password_path(socket, :new))
    end
    |> assign_defaults(session)
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
    {:ok, _} = Accounts.reset_user_password(socket.assigns.user, user_params)

    socket
    |> put_flash(:info, "Password reset successfully.")
    |> push_redirect(to: Routes.user_session_path(socket, :new))
    |> noreply()
  end
end
