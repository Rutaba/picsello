defmodule PicselloWeb.Shared.TopNav do
  @moduledoc """
    Live component for top_nav
  """

  use PicselloWeb, :live_component

  import PicselloWeb.LiveHelpers,
    only: [
      testid: 1,
      icon: 1,
      ok: 1,
      nav_link: 1
    ]

  import PicselloWeb.Shared.Sidebar, only: [initials_menu: 1, side_nav: 2]

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(
      Enum.into(assigns, %{
        tour_id: "current_user",
        inner_id: "initials-menu-inner-content"
      })
    )
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="border-b fixed left-0 right-0 top-0 z-40 bg-white">
      <div class="flex items-center px-6 center-container">
        <div id="hamburger-menu" class="relative cursor-pointer" phx-update="ignore" phx-hook="ToggleContent">
          <%= if @current_user do %>
          <div class="absolute left-0 z-10 flex flex-col items-start hidden cursor-default -top-2 toggle-content">
            <div class="p-4 -mb-2 bg-white shadow-md cursor-pointer text-base-300">
              <.icon name="close-x" class="w-4 h-4 stroke-current stroke-2" />
            </div>

            <nav class="flex flex-col bg-white rounded-lg shadow-md">
              <%= for %{heading: heading, items: items} <- side_nav(@socket, @current_user), @current_user do %>
                <p class="uppercase font-bold px-4 mt-2 mb-1 tracking-widest text-xs"><%= heading %></p>
                <%= for %{title: title, icon: icon, path: path} <- items do %>
                  <.nav_link title={title} to={path} socket={@socket} live_action={@live_action} current_user={@current_user} class="text-sm px-4 flex items-center py-1.5 whitespace-nowrap hover:bg-blue-planning-100 hover:font-bold" active_class="bg-blue-planning-100 font-bold">
                    <.icon name={icon} class="inline-block w-4 h-4 mr-2 text-blue-planning-300 shrink-0" />
                    <%= title %>
                  </.nav_link>
                <% end %>
              <% end %>
            </nav>
          </div>

          <.icon name="hamburger" class="h-4 text-base-300 w-9" />
          <% end %>
        </div>

        <nav class="flex items-center justify-center flex-1 mx-8 lg:justify-start">
          <%= live_redirect to: (apply Routes, (if @current_user, do: :home_path, else: :page_path), [@socket, :index]), title: "Picsello" do %>
            <.icon name="logo" class="my-4 w-28 h-9 mr-6" />
          <% end %>

          <div class="hidden lg:flex flex-grow">
            <%= for %{title: title, path: path, class: class, sub_nav_items: sub_nav_items, id: id} <- main_nav(@socket) do %>
              <%= if sub_nav_items do %>
                <.sub_nav socket={@socket} live_action={@live_action} current_user={@current_user} sub_nav_list={sub_nav_items} title={title} id={id} />
              <% else %>
                <.nav_link title={title} to={path} socket={@socket} live_action={@live_action} class={"hidden lg:block items-center transition-all font-bold text-blue-planning-300 hover:opacity-70 #{class}"}>
                  <%= title %>
                </.nav_link>
              <% end %>
            <% end %>
          </div>
        </nav>

        <.initials_menu {assigns} />
      </div>
    </header>
    """
  end

  defp sub_nav_list(socket, :get_booked),
    do: [
      %{
        title: "Booking Events",
        icon: "calendar",
        path: Routes.calendar_booking_events_path(socket, :index)
      },
      %{title: "Leads", icon: "three-people", path: Routes.job_path(socket, :leads)},
      %{title: "Marketing", icon: "bullhorn", path: Routes.marketing_path(socket, :index)}
    ]

  defp sub_nav_list(socket, :settings),
    do: [
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

  defp main_nav(socket) do
    [
      %{
        title: "Get booked",
        class: "mr-6",
        path: nil,
        sub_nav_items: sub_nav_list(socket, :get_booked),
        id: "get-booked-nav"
      },
      %{
        title: "Clients",
        class: "mr-6",
        path: Routes.clients_path(socket, :index),
        sub_nav_items: nil,
        id: "clients-nav"
      },
      %{
        title: "Galleries",
        class: "mr-6",
        path: Routes.gallery_path(socket, :galleries),
        sub_nav_items: nil,
        id: "galleries-nav"
      },
      %{
        title: "Jobs",
        class: "mr-6",
        path: Routes.job_path(socket, :jobs),
        sub_nav_items: nil,
        id: "jobs-nav"
      },
      %{
        title: "Inbox",
        class: "pl-4 border-l mr-6",
        path: Routes.inbox_path(socket, :index),
        sub_nav_items: nil,
        id: "inbox-nav"
      },
      %{
        title: "Calendar",
        class: "mr-6",
        path: Routes.calendar_index_path(socket, :index),
        sub_nav_items: nil,
        id: "calendar-nav"
      },
      %{
        title: "Settings",
        class: "mr-6",
        path: nil,
        sub_nav_items: sub_nav_list(socket, :settings),
        id: "settings-nav"
      },
      %{
        title: "Help",
        class: "mr-0 ml-auto",
        path: "https://support.picsello.com",
        sub_nav_items: nil,
        id: "help-nav"
      }
    ]
  end

  defp sub_nav(assigns) do
    ~H"""
      <div id={@id} class="relative cursor-pointer"  phx-update="ignore" phx-hook="ToggleContent" data-icon="toggle-icon">
        <div class="absolute left-0 z-10 flex flex-col items-start hidden cursor-default top-10 toggle-content">
          <nav class="flex flex-col bg-white rounded-lg shadow">
            <%= for %{title: title, icon: icon, path: path} <- @sub_nav_list, @current_user do %>
              <.nav_link title={title} to={path} socket={@socket} live_action={@live_action} current_user={@current_user} class="px-2 flex items-center py-2 text-sm whitespace-nowrap hover:bg-blue-planning-100 hover:font-bold" active_class="bg-blue-planning-100 font-bold">
                <.icon name={icon} class="inline-block w-4 h-4 mr-2 text-blue-planning-300 shrink-0" />
                <%= title %>
              </.nav_link>
            <% end %>
          </nav>
        </div>

        <div {testid("subnav-#{@title}")} class="group hidden lg:flex items-center mr-4 transition-all font-bold text-blue-planning-300 hover:opacity-70">
          <%= @title %> <.icon name="down" class="w-3 h-3 stroke-current stroke-3 ml-2 toggle-icon transition-transform group-hover:rotate-180" />
        </div>
      </div>
    """
  end

  def top_nav(assigns) do
    ~H"""
    <.live_component module={__MODULE__} id={assigns[:id] || "default-top-nav"} {assigns} />
    """
  end

  @impl true
  defdelegate handle_event(event, params, socket), to: PicselloWeb.Shared.Sidebar
end
