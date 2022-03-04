defmodule PicselloWeb.Live.User.Settings do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Accounts, Accounts.User, Organization, Repo}

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
      |> Keyword.merge(
        submit_changed_password: false,
        sign_out: false,
        page_title: "Settings",
        organization_name_changeset: organization_name_changeset(user),
        time_zone_changeset: time_zone_changeset(user)
      )
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

  defp organization_name_changeset(user, params \\ %{}) do
    user.organization
    |> Organization.name_changeset(params)
  end

  defp time_zone_changeset(user, params \\ %{}) do
    user
    |> User.time_zone_changeset(params)
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
        "validate",
        %{
          "action" => "update_name",
          "organization" => organization_params
        },
        %{assigns: %{current_user: user}} = socket
      ) do
    changeset =
      organization_name_changeset(user, organization_params)
      |> Map.put(:action, :validate)

    socket |> assign(:organization_name_changeset, changeset) |> noreply()
  end

  @impl true
  def handle_event(
        "validate",
        %{
          "action" => "update_time_zone",
          "user" => user_params
        },
        %{assigns: %{current_user: user}} = socket
      ) do
    changeset =
      time_zone_changeset(user, user_params)
      |> Map.put(:action, :validate)

    socket |> assign(:time_zone_changeset, changeset) |> noreply()
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
  def handle_event("save", %{"action" => "update_name"}, socket) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      close_label: "No, go back",
      confirm_event: "change-name",
      confirm_label: "Yes, change name",
      icon: "warning-orange",
      title: "Are you sure?",
      subtitle: "Changing your business name will update throughout Picsello."
    })
    |> noreply()
  end

  @impl true
  def handle_event(
        "save",
        %{
          "action" => "update_time_zone",
          "user" => user_params
        },
        %{assigns: %{current_user: user}} = socket
      ) do
    changeset = time_zone_changeset(user, user_params)

    case Repo.update(changeset) do
      {:ok, _user} ->
        socket
        |> put_flash(:success, "Timezone changed successfully")
        |> noreply()

      {:error, changeset} ->
        socket |> assign(time_zone_changeset: changeset) |> noreply()
    end
  end

  @impl true
  def handle_event("sign_out", _params, socket) do
    socket
    |> assign(sign_out: true)
    |> noreply()
  end

  @impl true
  def handle_event("intro_js" = event, params, socket),
    do: PicselloWeb.LiveHelpers.handle_event(event, params, socket)

  @impl true
  def handle_info(
        {:confirm_event, "change-name"},
        %{assigns: %{organization_name_changeset: changeset}} = socket
      ) do
    changeset = changeset |> Map.put(:action, nil)

    case Repo.update(changeset) do
      {:ok, _organization} ->
        socket
        |> close_modal()
        |> put_flash(:success, "Business name changed successfully")
        |> noreply()

      {:error, changeset} ->
        socket |> close_modal() |> assign(organization_name_changeset: changeset) |> noreply()
    end
  end

  def settings_nav(assigns) do
    assigns = assigns |> Enum.into(%{container_class: "", intro_id: nil})

    ~H"""
    <div class="bg-blue-planning-100"><h1 class="px-6 py-8 text-3xl font-bold center-container">Your Settings</h1></div>

    <div class={"flex flex-col flex-1 px-6 center-container #{@container_class}"} {if @intro_id, do: intro(@current_user, @intro_id), else: []}>
      <._settings_nav socket={@socket} live_action={@live_action} current_user={@current_user}>
        <:link to={{:user_settings, :edit}} >Account</:link>
        <:link to={{:package_templates, :index}} >Package Templates</:link>
        <:link hide={!show_pricing_tab?()} to={{:pricing, :index}} >Gallery Store Pricing</:link>
        <:link to={{:profile_settings, :index}} >Public Profile</:link>
        <:link to={{:contacts, :index}} >Contacts</:link>
        <:link to={{:brand_settings, :index}} >Brand</:link>
        <:link to={{:finance_settings, :index}} >Finances</:link>
      </._settings_nav>
      <hr />

      <%= render_block @inner_block %>
    </div>
    """
  end

  def card(assigns) do
    assigns = Enum.into(assigns, %{class: ""})

    ~H"""
    <div class={"flex overflow-hidden border rounded-lg #{@class}"}>
      <div class="w-4 border-r bg-blue-planning-300" />

      <div class="flex flex-col justify-between w-full p-4">
        <h1 class="mb-2 text-xl font-bold sm:text-2xl text-blue-planning-300"><%= @title %></h1>

        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  defp sign_out(assigns) do
    ~H"""
      <.form class={@class} for={:sign_out} action={Routes.user_session_path(@socket, :delete)} method="delete" phx-trigger-action={@sign_out} phx-submit="sign_out">
        <%= submit "Sign out", class: "btn-primary w-full" %>
      </.form>
    """
  end

  defp _settings_nav(assigns) do
    ~H"""
    <ul class="flex py-4 -ml-4 overflow-auto font-bold text-blue-planning-300">
    <%= for %{to: {path, action}} = link <- @link, !Map.get(link, :hide) do %>
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

  defp show_pricing_tab?,
    do: Enum.member?(Application.get_env(:picsello, :feature_flags, []), :show_pricing_tab)

  def time_zone_options() do
    TzExtra.countries_time_zones()
    |> Enum.sort_by(&{&1.utc_offset, &1.time_zone})
    |> Enum.map(&{"(GMT#{&1.pretty_utc_offset}) #{&1.time_zone}", &1.time_zone})
    |> Enum.uniq()
  end
end
