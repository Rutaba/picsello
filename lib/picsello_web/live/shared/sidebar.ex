defmodule PicselloWeb.Shared.Sidebar do
  @moduledoc """
    Live component for sidebar
  """

  alias Picsello.{
    Accounts.User,
    Repo
  }

  use PicselloWeb, :live_component

  import PicselloWeb.LiveHelpers,
    only: [
      icon: 1,
      ok: 1,
      noreply: 1,
      nav_link: 1,
      initials_circle: 1,
      classes: 2,
      tooltip: 1
    ]

  import Picsello.Onboardings, only: [user_update_sidebar_preference_changeset: 2]

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(
      Enum.into(assigns, %{
        is_drawer_open?: Map.get(assigns.current_user.onboarding, :sidebar_open_preference, true),
        is_mobile_drawer_open?: false,
        tour_id: "current_user",
        inner_id: "initials-menu-inner-content"
      })
    )
    |> ok()
  end

  @impl true
  def handle_event(
        "collapse",
        _unsigned_params,
        %{assigns: %{is_drawer_open?: is_drawer_open?, current_user: current_user}} = socket
      ) do
    current_user
    |> user_update_sidebar_preference_changeset(%{
      onboarding: %{sidebar_open_preference: !is_drawer_open?}
    })
    |> Repo.update!()

    socket
    |> push_event("sidebar:collapse", %{
      is_drawer_open: !is_drawer_open?
    })
    |> assign(:is_drawer_open?, !is_drawer_open?)
    |> noreply()
  end

  @impl true
  def handle_event(
        "open",
        _unsigned_params,
        %{assigns: %{is_mobile_drawer_open?: is_mobile_drawer_open?}} = socket
      ) do
    socket
    |> push_event("sidebar:mobile", %{
      is_mobile_drawer_open?: !is_mobile_drawer_open?
    })
    |> assign(:is_mobile_drawer_open?, !is_mobile_drawer_open?)
    |> noreply()
  end

  @impl true
  def handle_event(
        "feature-flag",
        _unsigned_params,
        %{assigns: %{current_user: current_user}} = socket
      ) do
    if FunWithFlags.enabled?(:sidebar_navigation, for: current_user) do
      FunWithFlags.disable(:sidebar_navigation, for_actor: current_user)
    else
      FunWithFlags.enable(:sidebar_navigation, for_actor: current_user)
    end

    socket
    |> put_flash(:success, "Beta feature toggled")
    |> push_redirect(to: Routes.home_path(socket, :index))
    |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="sidebar-wrapper" phx-hook="CollapseSidebar" data-drawer-open={"#{@is_drawer_open?}"} data-mobile-drawer-open={"#{@is_mobile_drawer_open?}"} class="z-50" data-target={@myself} phx-update="ignore">
      <div class="sm:hidden bg-white p-2 flex items-center justify-between fixed top-0 left-0 right-0 w-full">
        <button phx-click="open" phx-target={@myself} data-drawer-type="mobile" data-drawer-target="default-sidebar" data-drawer-toggle="default-sidebar" aria-controls="default-sidebar" type="button" class="inline-flex items-center p-2 mt-2 ms-3 text-sm text-gray-500 rounded-lg hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-gray-200 ">
          <span class="sr-only">Open sidebar</span>
          <.icon name="hamburger" class="h-4 text-base-300 w-9" />
        </button>
        <%= live_redirect to: (apply Routes, (if @current_user, do: :home_path, else: :page_path), [@socket, :index]), title: "Picsello" do %>
          <.icon name="logo" class="my-4 w-28 h-9 mr-6" />
        <% end %>
        <.initials_menu {assigns} />
      </div>
      <aside id="default-sidebar" class="fixed top-0 left-0 z-40 max-h-screen h-full transition-all" aria-label="Sidebar">
        <div class="h-full flex flex-col overflow-y-auto bg-white border-r border-r-base-200">
          <div class="flex items-center justify-between px-4">
            <%= live_redirect to: (apply Routes, (if @current_user, do: :home_path, else: :page_path), [@socket, :index]), title: "Picsello" do %>
              <.icon name="logo" class="my-4 w-28 h-9 mr-6 logo-full" />
              <.icon name="logo-badge" class="w-5 h-5 my-4 mr-6 logo-badge" />
            <% end %>
            <.initials_menu {assigns} tour_id="current_user_sidebar" id="initials-menu-sidebar" inner_id="initials-menu-inner-content-sidebar" />
          </div>
          <nav class="flex flex-col">
            <.nav_link title="Dashboard" to={Routes.home_path(@socket, :index)} socket={@socket} live_action={@live_action} current_user={@current_user} class="text-sm px-4 flex items-center py-2.5 whitespace-nowrap text-base-250 transition-all hover:bg-blue-planning-100" active_class="bg-blue-planning-100 text-black font-bold">
              <div class="inline" phx-hook="Tooltip" data-hint="Dashboard" data-position="right" id="tippydashboard">
                <.icon name="home" class="inline-block w-5 h-5 mr-2 text-black shrink-0" />
              </div>
              <span>Dashboard</span>
            </.nav_link>
            <%= for {%{heading: heading, is_default_opened?: is_default_opened?, items: items}, primary_index} <- Enum.with_index(side_nav(@socket, @current_user)), @current_user do %>
              <details open={is_default_opened?} class="group cursor-pointer">
                <summary class="flex justify-between items-center uppercase font-bold px-4 py-3 tracking-widest text-xs flex-shrink-0 whitespace-nowrap group cursor-pointer">
                  <span class="mr-2"><%= heading %></span>
                  <.icon name="down" class="w-4 h-4 stroke-current stroke-2 text-base flex-shrink-0 group-open:rotate-180" />
                </summary>
                <%= for {%{title: title, icon: icon, path: path}, secondary_index} <- Enum.with_index(items) do %>
                  <.nav_link title={title} to={path} socket={@socket} live_action={@live_action} current_user={@current_user} class="text-sm px-4 flex items-center py-2.5 whitespace-nowrap text-base-250 transition-all hover:bg-blue-planning-100" active_class="bg-blue-planning-100 text-black font-bold">
                    <div class="inline" phx-hook="Tooltip" data-hint={title} data-position="right" id={"tippy#{primary_index}#{secondary_index}"}>
                      <.icon name={icon} class="text-black inline-block w-5 h-5 mr-2 shrink-0"  />
                    </div>
                    <span><%= title %></span>
                  </.nav_link>
                <% end %>
              </details>
            <% end %>
            <.nav_link title="Settings" to={Routes.user_settings_path(@socket, :edit)} socket={@socket} live_action={@live_action} current_user={@current_user} class="text-sm px-4 flex items-center py-2.5 whitespace-nowrap text-base-250 transition-all hover:bg-blue-planning-100" active_class="bg-blue-planning-100 text-black font-bold">
              <div class="inline" phx-hook="Tooltip" data-hint="Settings" data-position="right" id="tippysettings">
                <.icon name="settings" class="inline-block w-5 h-5 mr-2 text-black shrink-0" />
              </div>
              <span>Settings</span>
            </.nav_link>
          </nav>
          <div class="mt-auto">
            <a href="https://form.typeform.com/to/vZiH7yCy" target="_blank" rel="noreferrer" class="text-sm link px-4 block py-2.5">
              <span>Submit nav/dashboard feedback</span>
            </a>
            <%= if @current_user && Application.get_env(:picsello, :intercom_id) do %>
              <.nav_link title="Help" to={"#help"} socket={@socket} live_action={@live_action} current_user={@current_user} class="text-sm px-4 flex items-center py-2.5 whitespace-nowrap text-base-250 transition-all hover:bg-blue-planning-100 open-help" active_class="bg-blue-planning-100 text-black font-bold">
                <div class="inline" phx-hook="Tooltip" data-hint="Help" data-position="right" id="tippyhelp">
                  <.icon name="question-mark" class="inline-block w-5 h-5 mr-2 text-black shrink-0" />
                </div>
                <span>Help</span>
              </.nav_link>
            <% end %>
            <button phx-click="collapse" phx-target={@myself} data-drawer-type="desktop" data-drawer-target="default-sidebar" data-drawer-toggle="default-sidebar" aria-controls="default-sidebar" type="button" class="text-sm px-4 sm:flex items-center py-2.5 whitespace-nowrap text-base-250 transition-all hover:bg-blue-planning-100 w-full hidden">
              <span class="sr-only">Open sidebar</span>
              <div class="inline" phx-hook="Tooltip" data-hint="Collapse" data-position="right" id="tippycollapse">
                <.icon name="collapse" class="inline-block w-5 h-5 mr-2 text-black shrink-0 transition-all" />
              </div>
              <span>Collapse</span>
            </button>
          </div>
        </div>
      </aside>
    </div>
    """
  end

  def initials_menu(assigns) do
    ~H"""
    <div id="initials-menu" class="relative flex flex-row justify-end cursor-pointer" phx-hook="ToggleContent">
      <%= if @current_user do %>
        <div id={@inner_id} class="absolute top-0 right-0 flex flex-col items-end hidden cursor-default text-base-300 toggle-content">
          <div class="p-4 -mb-2 bg-white shadow-md cursor-pointer text-base-300">
            <.icon name="close-x" class="w-4 h-4 stroke-current stroke-2" />
          </div>
          <div class="bg-gray-100 rounded-lg shadow-md w-max z-30">
            <%= live_redirect to: Routes.user_settings_path(@socket, :edit), title: "Account", class: "flex items-center px-2 py-2 bg-white" do %>
              <.initials_circle user={@current_user} />
              <div class="ml-2 font-bold">Account</div>
            <% end %>

            <%= if FunWithFlags.enabled?(:photo_lab) do %>
              <div class="bg-white px-2">
                <hr class="pt-2" />
                <p class="font-semibold">Beta Features</p>
                <div class="flex justify-between items-center text-sm pb-2">
                  <p class="text-base-250">Sidebar Navigation <.tooltip id="sidebar-nav" class="" content="Try out an easier to use navigation. We'd love your feedback. (You will be directed to your dashboard when toggled.)"/></p>
                  <button type="button" class="cursor-pointer" phx-click="feature-flag" phx-target={@myself}>
                    <div class="flex">
                      <div class={classes("rounded-full w-7 p-0.5 flex border border-blue-planning-300", %{"bg-blue-planning-300 justify-end" => FunWithFlags.enabled?(:sidebar_navigation, for: @current_user), "bg-base-100" => !FunWithFlags.enabled?(:sidebar_navigation, for: @current_user)})}>
                        <div class={classes("rounded-full h-3 w-3", %{"bg-base-100" => FunWithFlags.enabled?(:sidebar_navigation, for: @current_user), "bg-blue-planning-300" => !FunWithFlags.enabled?(:sidebar_navigation, for: @current_user)})}></div>
                      </div>
                    </div>
                  </button>
                </div>
                <hr />
              </div>
            <% end %>

            <%= if Enum.any?(@current_user.onboarding.intro_states) do %>
              <.live_component module={PicselloWeb.Live.RestartTourComponent} id={@tour_id}, current_user={@current_user} />
            <% end %>
            <.form :let={_} for={%{}} as={:sign_out} action={Routes.user_session_path(@socket, :delete)} method="delete">
              <%= submit "Logout", class: "text-center py-2 w-full" %>
            </.form>
          </div>
        </div>
        <div class="flex flex-col items-center justify-center text-sm text-base-300 bg-gray-100 rounded-full w-9 h-9 pb-0.5" title={@current_user.name}>
          <%= User.initials @current_user %>
        </div>
      <% end %>
    </div>
    """
  end

  def get_classes_for_main(current_user) do
    if FunWithFlags.enabled?(:sidebar_navigation, for: current_user) do
      %{
        "sm:ml-64" => Map.get(current_user.onboarding, :sidebar_open_preference, true),
        "sm:ml-12" => !Map.get(current_user.onboarding, :sidebar_open_preference, true)
      }
    else
      %{}
    end
  end

  defp side_nav(socket, _current_user) do
    [
      %{
        heading: "Monetize",
        is_default_opened?: true,
        items: [
          %{title: "Leads", icon: "three-people", path: Routes.job_path(socket, :leads)},
          %{
            title: "Jobs",
            icon: "camera-check",
            path: Routes.job_path(socket, :jobs)
          },
          %{
            title: "Galleries",
            icon: "upload",
            path: Routes.gallery_path(socket, :galleries)
          },
          %{
            title: "Booking Events",
            icon: "calendar",
            path: Routes.calendar_booking_events_path(socket, :index)
          },
          %{
            title: "Clients",
            icon: "client-icon",
            path: Routes.clients_path(socket, :index)
          }
        ]
      },
      %{
        heading: "Manage",
        is_default_opened?: true,
        items: [
          %{
            title: "Inbox",
            icon: "envelope",
            path: Routes.inbox_path(socket, :index)
          },
          %{
            title: "Calendar",
            icon: "calendar",
            path: Routes.calendar_index_path(socket, :index)
          },
          %{title: "Marketing", icon: "bullhorn", path: Routes.marketing_path(socket, :index)}
        ]
      },
      %{
        heading: "Admin & Docs",
        is_default_opened?: false,
        items: [
          %{
            title: "Automations (Beta)",
            icon: "play-icon",
            path: Routes.email_automations_index_path(socket, :index)
          },
          %{
            title: "Packages",
            icon: "package",
            path: Routes.package_templates_path(socket, :index)
          },
          %{
            title: "Contracts",
            icon: "contract",
            path: Routes.contracts_index_path(socket, :index)
          },
          %{
            title: "Questionnaires",
            icon: "questionnaire",
            path: Routes.questionnaires_index_path(socket, :index)
          }
        ]
      }
    ]
  end

  def main_header(assigns) do
    ~H"""
    <.live_component module={__MODULE__} id={assigns[:id] || "default-sidebar"} {assigns} />
    """
  end
end
