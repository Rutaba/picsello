defmodule PicselloWeb.Live.User.Settings do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Accounts, Accounts.User}

  require Logger

  @changeset_types %{current_password: :string, email: :string}

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket), do: send(self(), :check_stripe)
    %{assigns: %{current_user: user}} = socket = assign_defaults(socket, session)

    socket
    |> assign(
      email_changeset: email_changeset(user),
      password_changeset: password_changeset(user),
      submit_changed_password: false,
      show_stripe: false
    )
    |> ok()
  end

  defp email_changeset(user, params \\ %{}) do
    {user, @changeset_types}
    |> Ecto.Changeset.cast(params, [:current_password])
    |> User.email_changeset(params)
    |> Ecto.Changeset.validate_required(:current_password)
  end

  defp password_changeset(user, params \\ %{}) do
    user
    |> Ecto.Changeset.cast(params, [:password])
    |> User.validate_password([])
  end

  @impl true
  def handle_event(
        "validate",
        %{
          "action" => "update_email",
          "user" => user_params
        },
        %{assigns: %{current_user: user}} = socket
      ) do
    changeset =
      user
      |> email_changeset(user_params)
      |> Map.put(:action, :validate)

    socket |> assign(:email_changeset, changeset) |> noreply()
  end

  @impl true
  def handle_event(
        "validate",
        %{
          "action" => "update_password",
          "user" => user_params
        },
        %{assigns: %{current_user: user}} = socket
      ) do
    changeset =
      user
      |> password_changeset(user_params)
      |> Map.put(:action, :validate)

    socket |> assign(:password_changeset, changeset) |> noreply()
  end

  @impl true
  def handle_event(
        "save",
        %{
          "action" => "update_email",
          "user" => %{"current_password" => password} = user_params
        },
        %{assigns: %{current_user: user}} = socket
      ) do
    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_update_email_instructions(
          applied_user,
          user.email,
          &Routes.user_settings_url(socket, :confirm_email, &1)
        )

        socket
        |> put_flash(
          :info,
          "A link to confirm your email change has been sent to the new address."
        )
        |> noreply()

      {:error, changeset} ->
        socket |> assign(email_changeset: changeset) |> noreply()
    end
  end

  @impl true
  def handle_event(
        "save",
        %{
          "action" => "update_password",
          "user" => user_params
        },
        %{assigns: %{current_user: user}} = socket
      ) do
    changeset =
      password_changeset(user, user_params)
      |> User.validate_current_password(
        user_params |> Map.get("password_to_change"),
        :password_to_change
      )
      |> Map.put(:action, :validate)

    socket
    |> assign(
      password_changeset: changeset,
      submit_changed_password: changeset.valid?
    )
    |> noreply()
  end

  @impl true
  def handle_event("open-stripe", _params, %{assigns: %{current_user: current_user}} = socket) do
    redirect_url = Routes.user_settings_url(socket, :edit)

    case payments().login_link(current_user, redirect_url: redirect_url) do
      {:ok, url} ->
        socket |> redirect(external: url) |> noreply()

      error ->
        Logger.error(error)
        socket |> put_flash(:error, "Can't open stripe login link.") |> noreply()
    end
  end

  @impl true
  def handle_info(:check_stripe, %{assigns: %{current_user: current_user}} = socket) do
    case payments().status(current_user) do
      {:ok, :charges_enabled} ->
        socket |> assign(show_stripe: true) |> noreply()

      {:ok, _} ->
        socket |> noreply()

      error ->
        Logger.error(error)
        socket |> put_flash(:error, "Couldn't reach stripe.") |> noreply()
    end
  end

  defp payments, do: Application.get_env(:picsello, :payments)
end
