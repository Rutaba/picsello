defmodule PicselloWeb.LiveHelpers do
  @moduledoc "used in both views and components"
  use Phoenix.Component

  import Phoenix.LiveView, only: [assign: 2]
  import PicselloWeb.Router.Helpers, only: [static_path: 2]
  import PicselloWeb.Gettext, only: [dyn_gettext: 1]

  def live_modal(_socket, component, opts) do
    path = Keyword.fetch!(opts, :return_to)
    modal_opts = [id: :modal, return_to: path, component: component, opts: opts]
    live_component(PicselloWeb.ModalComponent, modal_opts)
  end

  def open_modal(socket, component, assigns \\ %{})

  # main process, modal pid is assigned
  def open_modal(
        %{assigns: %{modal_pid: modal_pid} = parent_assigns} = socket,
        component,
        %{assigns: assigns} = config
      )
      when is_pid(modal_pid) do
    send(
      modal_pid,
      {:modal, :open, component,
       config
       |> Map.put(
         :assigns,
         assigns
         |> Map.merge(Map.take(parent_assigns, [:live_action]))
       )}
    )

    socket
  end

  # called with raw assigns map
  def open_modal(
        %{assigns: %{modal_pid: modal_pid}} = socket,
        component,
        assigns
      )
      when is_pid(modal_pid),
      do: socket |> open_modal(component, %{assigns: assigns})

  # modal process
  def open_modal(
        %{view: PicselloWeb.LiveModal} = socket,
        component,
        config
      ),
      do: socket |> assign(modal_pid: self()) |> open_modal(component, config)

  # main process, before modal pid is assigned
  def open_modal(
        socket,
        component,
        config
      ) do
    socket
    |> assign(queued_modal: {component, config})
  end

  # close from main process
  def close_modal(%{assigns: %{modal_pid: modal_pid}} = socket) do
    send(modal_pid, {:modal, :close})

    socket
  end

  # close from within modal process
  def close_modal(socket) do
    send(self(), {:modal, :close})

    socket
  end

  def strftime("" <> time_zone, time, format) do
    time
    |> DateTime.shift_zone!(time_zone)
    |> Calendar.strftime(format)
  end

  def icon(%{name: name} = assigns) do
    assigns =
      assigns
      |> Enum.into(%{
        width: nil,
        height: nil,
        class: nil,
        path:
          assigns
          |> Map.get(:socket, PicselloWeb.Endpoint)
          |> static_path(Picsello.Icon.public_path(name))
      })

    ~H"""
    <svg width={@width} height={@height} class={@class}>
      <use href={@path} />
    </svg>
    """
  end

  def icon_button(assigns) do
    assigns =
      assigns
      |> Map.put(:rest, Map.drop(assigns, [:color, :icon, :inner_block, :class]))
      |> Enum.into(%{class: ""})

    ~H"""
    <button type="button" class={"flex items-center px-2 py-1 border rounded-lg text-2m border-#{@color} #{@class}"} {@rest}>
      <.icon name={@icon} class={"w-4 h-4 mr-1 fill-current text-#{@color}"} />
      <%= render_block(@inner_block) %>
    </button>
    """
  end

  def ok(socket), do: {:ok, socket}
  def noreply(socket), do: {:noreply, socket}

  def testid(id) do
    if Application.get_env(:picsello, :render_test_ids) do
      %{"data-testid" => id}
    else
      %{}
    end
  end

  def classes(%{} = optionals), do: classes([], optionals)
  def classes(constants), do: classes(constants, %{})

  def classes(nil, optionals), do: classes([], optionals)

  def classes("" <> constant, optionals) do
    classes([constant], optionals)
  end

  def classes(constants, optionals) do
    [
      constants,
      optionals
      |> Enum.filter(&elem(&1, 1))
      |> Enum.map(&elem(&1, 0))
    ]
    |> Enum.concat()
    |> Enum.join(" ")
  end

  def path_active?(
        %{
          view: socket_view,
          router: router,
          host_uri: %{host: host}
        },
        socket_live_action,
        path
      ),
      do:
        match?(
          %{phoenix_live_view: {view, live_action, _, _}}
          when view == socket_view and live_action == socket_live_action,
          Phoenix.Router.route_info(router, "GET", path, host)
        )

  def nav_link(assigns) do
    ~H"""
      <%= live_redirect to: @to, title: @title, class: classes(@class, %{@active_class => path_active?(@socket, @live_action, @to)}) do %>
        <%= render_block(@inner_block) %>
      <% end %>
    """
  end

  def live_link(%{} = assigns) do
    ~H"""
    <%= assigns |> Map.drop([:__changed__, :inner_block]) |> Enum.to_list |> live_redirect do %>
      <%= render_block(@inner_block) %>
    <% end %>
    """
  end

  def crumbs(assigns) do
    assigns = Enum.into(assigns, %{class: "text-xs text-blue-planning-200"})

    ~H"""
    <div class={@class}>
      <%= for crumb <- Enum.slice(@crumb, 0..-2) do %>
        <.live_link {crumb}><%= render_slot(crumb) %></.live_link>
        <.icon name="forth" class="inline-block w-2 h-2 stroke-current" />
      <% end %>
      <span class="font-semibold"><%= render_slot(List.last(@crumb)) %></span>
    </div>
    """
  end

  def job_type_option(assigns) do
    ~H"""
      <label class={classes(
        "flex items-center p-2 border rounded-lg hover:bg-blue-planning-100 hover:bg-opacity-60 cursor-pointer font-semibold text-sm leading-tight sm:text-base",
        %{"border-blue-planning-300 bg-blue-planning-100" => @checked}
      )}>
        <input class="hidden" type={@type} name={@name} value={@job_type} checked={@checked} />

        <div class={classes(
          "flex items-center justify-center w-7 h-7 ml-1 mr-3 rounded-full flex-shrink-0",
          %{"bg-blue-planning-300 text-white" => @checked, "bg-base-200" => !@checked}
        )}>
          <.icon name={@job_type} class="fill-current" width="14" height="14" />
        </div>

        <%= dyn_gettext @job_type %>
      </label>
    """
  end

  @badge_colors %{
    gray: "bg-gray-200",
    blue: "bg-blue-planning-100 text-blue-planning-300 group-hover:bg-white",
    green: "bg-green-finances-100 text-green-finances-300",
    red: "bg-red-sales-100 text-red-sales-300"
  }

  def badge(%{color: color} = assigns) do
    assigns =
      assigns |> Map.put(:color_style, Map.get(@badge_colors, color)) |> Enum.into(%{class: ""})

    ~H"""
    <span role="status" class={"px-2 py-0.5 text-xs font-semibold rounded #{@color_style} #{@class}"} >
      <%= render_block @inner_block %>
    </span>
    """
  end

  def filesize(byte_size) when is_integer(byte_size),
    do: Size.humanize!(byte_size, spacer: "")

  def display_photo(key), do: Picsello.Galleries.Workers.PhotoStorage.path_to_url(key)

  def display_photo(nil), do: "/images/gallery-icon.png"
end
