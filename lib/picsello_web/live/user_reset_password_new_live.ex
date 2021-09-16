defmodule PicselloWeb.UserResetPasswordNewLive do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Accounts, Accounts.User}

  @impl true
  def mount(_params, session, socket) do
    changeset = User.reset_password_changeset()

    socket
    |> assign_defaults(session)
    |> assign(:page_title, "Reset Password")
    |> assign(changeset: changeset, trigger_submit: false)
    |> ok()
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      %User{}
      |> User.reset_password_changeset(params)
      |> Map.put(:action, :validate)

    socket |> assign(changeset: changeset) |> noreply()
  end

  @impl true
  def handle_event("submit", %{"user" => user_params}, socket) do
    result =
      if user = Accounts.get_user_by_email(user_params["email"]) do
        Accounts.deliver_user_reset_password_instructions(
          user,
          &Routes.user_reset_password_url(socket, :edit, &1)
        )
      else
        {:ok, :user_not_found}
      end

    case result do
      {:ok, _} ->
        socket
        |> put_flash(
          :info,
          "If your email is in our system, you will receive instructions to reset your password shortly."
        )
        |> redirect(to: "/")
        |> noreply()

      _ ->
        socket
        |> put_flash(:error, "Unexpected error. Please try again.")
        |> noreply()
    end
  end
end
