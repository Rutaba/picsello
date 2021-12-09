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
      <._settings_nav socket={@socket} live_action={@live_action}>
        <:link to={{:user_settings, :edit}} >Profile</:link>
        <:link to={{:package_templates, :index}} >Package Templates</:link>
        <:link to={{:pricing, :index}} >Gallery Store Pricing</:link>
        <:link to={{:profile_settings, :index}} >Public Profile</:link>
      </._settings_nav>
      <hr />

      <%= render_block @inner_block %>
    </div>
    """
  end

  defp _settings_nav(assigns) do
    ~H"""
    <ul class="flex py-4 -ml-4 overflow-auto font-bold text-blue-planning-300">
      <%= for %{to: {path, action}} = link <- @link do %>
        <li>
          <.nav_link title={path} let={active} to={apply(Routes, :"#{path}_path", [@socket, action])} class="block rounded-lg whitespace-nowrap" active_class="bg-blue-planning-100 text-base-300" socket={@socket} live_action={@live_action}>
            <div {if active, do: %{id: "active-settings-nav-link", phx_hook: "ScrollIntoView"}, else: %{}} class="px-4 py-3">
              <%= render_slot(link) %>
            </div>
          </.nav_link>
        </li>
      <% end %>
    </ul>
    """
  end
end
