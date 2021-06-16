defmodule PicselloWeb.UserSessionNewLive do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Accounts, Accounts.User}

  @impl true
  def mount(_params, session, socket) do
    changeset = User.new_session_changeset()

    socket
    |> assign_defaults(session)
    |> assign(changeset: changeset, error_message: nil, trigger_submit: false)
    |> ok()
  end

  @impl true
  def handle_event("validate", %{"user" => %{"trigger_submit" => "true"}}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    changeset =
      %User{}
      |> User.new_session_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event("submit", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> User.new_session_changeset(user_params)
      |> Map.put(:action, :validate)

    user =
      changeset.valid? &&
        Accounts.get_user_by_email_and_password(user_params["email"], user_params["password"])

    {:noreply,
     assign(socket,
       changeset: changeset,
       error_message: if(user, do: nil, else: "Invalid email or password"),
       trigger_submit: !!user
     )}
  end
end
