defmodule PicselloWeb.Shared.Sidebar do
  @moduledoc """
    Helper functions to use the Sticky upload component
  """

  alias Picsello.{
    Accounts.User,
    Repo
  }

  use PicselloWeb, :live_component

  import PicselloWeb.LiveHelpers,
    only: [
      testid: 1,
      icon: 1,
      ok: 1,
      noreply: 1,
      nav_link: 1,
      initials_circle: 1
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
  def render(assigns) do
    ~H"""
    <div id="sidebar-wrapper" phx-hook="CollapseSidebar" data-drawer-open={"#{@is_drawer_open?}"} data-mobile-drawer-open={"#{@is_mobile_drawer_open?}"} class="z-50" data-target={@myself} phx-update="ignore">
      <div class="sm:hidden bg-white p-2 flex items-center justify-between fixed top-0 left-0 right-0 w-full">
        <button phx-click="open" phx-target={@myself} data-drawer-type="mobile" data-drawer-target="default-sidebar" data-drawer-toggle="default-sidebar" aria-controls="default-sidebar" type="button" class="inline-flex items-center p-2 mt-2 ms-3 text-sm text-gray-500 rounded-lg hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-gray-200 dark:text-gray-400 dark:hover:bg-gray-700 dark:focus:ring-gray-600">
          <span class="sr-only">Open sidebar</span>
          <.icon name="hamburger" class="h-4 text-base-300 w-9" />
        </button>
        <%= live_redirect to: (apply Routes, (if @current_user, do: :home_path, else: :page_path), [@socket, :index]), title: "Picsello" do %>
          <.icon name="logo" class="my-4 w-28 h-9 mr-6" />
        <% end %>
        <.initials_menu {assigns} />
      </div>
      <aside id="default-sidebar" class="fixed top-0 left-0 z-40 h-screen transition-all" aria-label="Sidebar">
        <div class="h-full overflow-y-auto bg-white border-r border-r-base-200">
          <div class="flex items-center justify-between px-4">
            <%= live_redirect to: (apply Routes, (if @current_user, do: :home_path, else: :page_path), [@socket, :index]), title: "Picsello" do %>
              <.icon name="logo" class="my-4 w-28 h-9 mr-6" />
            <% end %>
            <.initials_menu {assigns} tour_id="current_user_sidebar" id="initials-menu-sidebar" inner_id="initials-menu-inner-content-sidebar" />
          </div>
          <nav class="flex flex-col">
            <%= for %{heading: heading, items: items} <- side_nav(@socket, @current_user), @current_user do %>
              <div>
                <p class="uppercase font-bold px-4 mt-2 mb-1 tracking-widest text-xs flex-shrink-0 whitespace-nowrap"><%= heading %></p>
                <%= for %{title: title, icon: icon, path: path} <- items do %>
                  <.nav_link title={title} to={path} socket={@socket} live_action={@live_action} current_user={@current_user} class="text-sm px-4 flex items-center py-2.5 whitespace-nowrap text-base-250 transition-all hover:bg-blue-planning-100" active_class="bg-blue-planning-100 text-black font-bold">
                    <.icon name={icon} class="text-black inline-block w-5 h-5 mr-2 shrink-0" />
                    <span><%= title %></span>
                  </.nav_link>
                <% end %>
              </div>
            <% end %>
          </nav>
          <button phx-click="collapse" phx-target={@myself} data-drawer-type="desktop" data-drawer-target="default-sidebar" data-drawer-toggle="default-sidebar" aria-controls="default-sidebar" type="button" class="inline-flex items-center p-2 mt-2 ms-3 text-sm text-gray-500 rounded-lg hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-gray-200 dark:text-gray-400 dark:hover:bg-gray-700 dark:focus:ring-gray-600 sm:block hidden">
            <span class="sr-only">Open sidebar</span>
            Collapse
          </button>
        </div>
      </aside>
    </div>
    """
  end

  defp initials_menu(assigns) do
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
              <div class="ml-2 font-semibold">Account</div>
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

  def side_nav(socket, _current_user) do
    [
      %{
        heading: "Get Booked",
        items: [
          %{
            title: "Booking Events",
            icon: "calendar",
            path: Routes.calendar_booking_events_path(socket, :index)
          },
          %{title: "Leads", icon: "three-people", path: Routes.job_path(socket, :leads)},
          %{title: "Marketing", icon: "bullhorn", path: Routes.marketing_path(socket, :index)}
        ]
      },
      %{
        heading: "Manage",
        items: [
          %{
            title: "Clients",
            icon: "client-icon",
            path: Routes.clients_path(socket, :index)
          },
          %{
            title: "Galleries",
            icon: "upload",
            path: Routes.gallery_path(socket, :galleries)
          },
          %{
            title: "Jobs",
            icon: "camera-check",
            path: Routes.job_path(socket, :jobs)
          },
          %{
            title: "Inbox",
            icon: "envelope",
            path: Routes.inbox_path(socket, :index)
          },
          %{
            title: "Calendar",
            icon: "calendar",
            path: Routes.calendar_index_path(socket, :index)
          }
        ]
      },
      %{
        heading: "Settings",
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
          },
          %{
            title: "Calendar",
            icon: "calendar",
            path: Routes.calendar_settings_path(socket, :settings)
          },
          %{
            title: "Gallery",
            icon: "gallery-settings",
            path: Routes.gallery_global_settings_index_path(socket, :edit)
          },
          %{
            title: "Finances",
            icon: "money-bags",
            path: Routes.finance_settings_path(socket, :index)
          },
          %{
            title: "Brand",
            icon: "brand",
            path: Routes.brand_settings_path(socket, :index)
          },
          %{
            title: "Public Profile",
            icon: "website",
            path: Routes.profile_settings_path(socket, :index)
          },
          %{
            title: "Account",
            icon: "settings",
            path: Routes.user_settings_path(socket, :edit)
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
