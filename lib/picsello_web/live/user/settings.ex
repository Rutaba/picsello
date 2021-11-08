defmodule PicselloWeb.Live.User.Settings do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Accounts, Accounts.User}

  require Logger

  @changeset_types %{current_password: :string, email: :string}

  @impl true
  def mount(_params, _session, %{assigns: %{current_user: user}} = socket) do
    socket
    |> assign(
      case user.sign_up_auth_provider do
        :password ->
          [email_changeset: email_changeset(user), password_changeset: password_changeset(user)]

        _ ->
          [email_changeset: nil, password_changeset: nil]
      end
      |> Keyword.merge(submit_changed_password: false, sign_out: false, page_title: "Settings")
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
  def handle_event("sign_out", _params, socket) do
    socket
    |> assign(sign_out: true)
    |> noreply()
  end

  def settings_nav(assigns) do
    assigns = assigns |> Enum.into(%{container_class: ""})

    ~H"""
    <div class="bg-blue-planning-100"><h1 class="px-6 py-8 text-3xl font-bold center-container">Your Settings</h1></div>

    <div class={"flex flex-col flex-1 px-6 center-container #{@container_class}"}>
      <ul class="flex my-4 font-bold text-blue-planning-300">
        <li>
          <.nav_link title="Profile" to={Routes.user_settings_path(@socket, :edit)} class="block px-4 py-3 rounded-lg" active_class="bg-blue-planning-100 text-base-300" socket={@socket} live_action={@live_action}>
            Profile
          </.nav_link>
        </li>

        <li>
          <.nav_link title="Package Templates" to={Routes.package_templates_path(@socket, :index)} class="block px-4 py-3 rounded-lg" active_class="bg-blue-planning-100 text-base-300" socket={@socket} live_action={@live_action}>
            Package Templates
          </.nav_link>
        </li>

        <li>
          <.nav_link title="Gallery Store Pricing" to={Routes.pricing_path(@socket, :index)} class="block px-4 py-3 rounded-lg" active_class="bg-blue-planning-100 text-base-300" socket={@socket} live_action={@live_action}>
            Gallery Store Pricing
          </.nav_link>
        </li>
      </ul>

      <hr />

      <%= render_block @inner_block %>
    </div>
    """
  end
end
