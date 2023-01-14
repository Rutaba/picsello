defmodule PicselloWeb.LiveHelpers do
  @moduledoc "used in both views and components"
  use Phoenix.Component

  alias Picsello.{Onboardings, PaymentSchedules, BookingProposal}

  import Phoenix.LiveView,
    only: [get_connect_params: 1, assign: 2, assign_new: 3, redirect: 2, put_flash: 3]

  import PicselloWeb.Router.Helpers, only: [static_path: 2]
  import PicselloWeb.Gettext, only: [dyn_gettext: 1]
  require Logger

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
        style: nil,
        path: Picsello.Icon.public_path(name, PicselloWeb.Endpoint, &static_path/2)
      })

    ~H"""
    <svg width={@width} height={@height} class={@class} style={@style}>
      <use href={@path} />
    </svg>
    """
  end

  def icon_button(%{href: href} = assigns) do
    assigns =
      assigns
      |> Map.put(
        :rest,
        Map.drop(assigns, [:color, :icon, :inner_block, :class, :disabled, :target])
      )
      |> Enum.into(%{class: "", target: nil, disabled: false, inner_block: nil})

    ~H"""
    <a href={if @disabled, do: "javascript:void(0)", else: href} target={unless @disabled, do: @target} class={classes("btn-tertiary flex items-center px-2 py-1 font-sans rounded-lg hover:opacity-75 text-#{@color} #{@class}", %{"opacity-30 hover:opacity-30 hover:cursor-not-allowed" => @disabled})} {@rest}>
      <.icon name={@icon} class={classes("w-4 h-4 fill-current text-#{@color}", %{"mr-3" => @inner_block})} />
      <%= if @inner_block do %>
        <%= render_block(@inner_block) %>
      <% end %>
    </a>
    """
  end

  def icon_button(assigns) do
    assigns =
      assigns
      |> Map.put(:rest, Map.drop(assigns, [:color, :icon, :inner_block, :class, :disabled]))
      |> Enum.into(%{class: "", disabled: false, inner_block: nil})

    ~H"""
    <button type="button" class={classes("btn-tertiary flex items-center px-2 py-1 font-sans rounded-lg hover:opacity-75 text-#{@color} #{@class}", %{"opacity-50 hover:opacity-30 hover:cursor-not-allowed" => @disabled})}} disabled={@disabled} {@rest}>
      <.icon name={@icon} class={classes("w-4 h-4 fill-current text-#{@color}", %{"mr-3" => @inner_block})} />
      <%= if @inner_block do %>
        <%= render_block(@inner_block) %>
      <% end %>
    </button>
    """
  end

  def icon_button_simple(assigns) do
    assigns =
      assigns
      |> Map.put(:rest, Map.drop(assigns, [:color, :icon, :inner_block, :class, :disabled]))
      |> Enum.into(%{class: "", disabled: false, inner_block: nil})

    ~H"""
    <button type="button" class={classes("btn-tertiary flex items-center px-2 py-1 font-sans border hover:opacity-75 #{@class}", %{"opacity-50 hover:opacity-30 hover:cursor-not-allowed" => @disabled})}} disabled={@disabled} {@rest}>
      <.icon name={@icon} class="w-2 h-3 fill-current text-#{@color}" />
    </button>
    """
  end

  def ok(socket), do: {:ok, socket}
  def ok(socket, opts), do: {:ok, socket, opts}
  def noreply(socket), do: {:noreply, socket}
  def reply(socket, payload), do: {:reply, payload, socket}

  def testid(id) do
    if Application.get_env(:picsello, :render_test_ids) do
      %{"data-testid" => id}
    else
      %{}
    end
  end

  def classes(nil), do: ""
  def classes(%{} = optionals), do: classes([], optionals)
  def classes([{_k, _v} | _] = optionals), do: classes([], Map.new(optionals))
  def classes(["" <> _constant | _] = constants), do: classes(constants, %{})

  def classes(nil, optionals), do: classes([], optionals)
  def classes("" <> constant, optionals), do: classes([constant], optionals)

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

  defp path_active?(
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

  defp is_active(assigns) do
    ~H"""
      <%= render_slot(@inner_block, path_active?(@socket, @live_action, @path)) %>
    """
  end

  def nav_link(assigns) do
    assigns =
      assign_new(assigns, :help_scout_or_external_link, fn ->
        if String.starts_with?(assigns.to, "#business-coaching") do
          help_scout_output(assigns.current_user, :help_scout_id_business)
        else
          %{target: "_blank", rel: "noopener noreferrer"}
        end
      end)

    ~H"""
      <.is_active socket={@socket} live_action={@live_action} path={@to} let={active} >
        <%= if String.starts_with?(@to, "/") do %>
          <%= live_redirect to: @to, title: @title, class: classes(@class, %{@active_class => active}) do %>
            <%= render_slot(@inner_block, active) %>
          <% end %>
        <% else %>
          <a href={@to} class={@class} {@help_scout_or_external_link}>
            <%= render_slot(@inner_block, active) %>
          </a>
        <% end %>
      </.is_active>
    """
  end

  def live_link(%{} = assigns) do
    ~H"""
    <%= assigns |> Map.drop([:__changed__, :inner_block]) |> Enum.to_list |> live_redirect do %><%= render_block(@inner_block) %><% end %>
    """
  end

  def crumbs(assigns) do
    assigns = Enum.into(assigns, %{class: "text-xs text-base-250"})

    ~H"""
    <div class={@class}>
      <%= for crumb <- Enum.slice(@crumb, 0..-2) do %>
        <.live_link {crumb}><%= render_slot(crumb) %></.live_link>
        <.icon name="forth" class="inline-block w-2 h-2 stroke-current stroke-2" />
      <% end %>
      <span class="font-semibold"><%= render_slot(List.last(@crumb)) %></span>
    </div>
    """
  end

  @job_type_colors %{
    "blue" => {"bg-blue-planning-100", "border-blue-planning-300", "bg-blue-planning-300"},
    "black" => {"bg-base-200", "border-base-300", "bg-base-300"}
  }
  def job_type_option(assigns) do
    assigns = Enum.into(assigns, %{disabled: false, class: "", color: "blue"})

    {bg_light, border_dark, bg_dark} = @job_type_colors |> Map.get(assigns.color)

    ~H"""
      <label class={classes(
        "flex items-center p-2 border rounded-lg hover:#{bg_light}/60 cursor-pointer font-semibold text-sm leading-tight sm:text-base #{@class}",
        %{"#{border_dark} #{bg_light}" => @checked}
      )}>
        <input class="hidden" type={@type} name={@name} value={@job_type} checked={@checked} disabled={@disabled} />

        <div class={classes(
          "flex items-center justify-center w-7 h-7 ml-1 mr-3 rounded-full flex-shrink-0",
          %{"#{bg_dark} text-white" => @checked, "bg-base-200" => !@checked}
        )}>
          <.icon name={@job_type} class="fill-current" width="14" height="14" />
        </div>

        <%= dyn_gettext @job_type %>
      </label>
    """
  end

  @badge_colors %{
    filled: %{
      gray: "rounded bg-gray-200",
      blue: "rounded bg-blue-planning-100 text-blue-planning-300 group-hover:bg-white",
      green: "rounded bg-green-finances-100 text-green-finances-300",
      red: "rounded bg-red-sales-100 text-red-sales-300"
    },
    outlined: %{
      gray: "border border-base-250 text-base-250",
      blue: "border border-blue-planning-300 text-blue-planning-300 group-hover:bg-white",
      green: "border border-green-finances-300 text-green-finances-300",
      red: "border border-red-sales-300 text-red-sales-300"
    }
  }

  def badge(%{color: color} = assigns) do
    badge_mode = assigns |> Map.get(:mode, :filled)

    assigns =
      assigns
      |> Map.put(:color_style, @badge_colors |> Map.get(badge_mode) |> Map.get(color))
      |> Enum.into(%{class: ""})

    ~H"""
    <span role="status" class={"px-2 py-0.5 text-xs font-semibold #{@color_style} #{@class}"} >
      <%= render_block @inner_block %>
    </span>
    """
  end

  def filesize(byte_size) when is_integer(byte_size),
    do: Size.humanize!(byte_size, spacer: "")

  def to_integer(int) when is_integer(int), do: int

  def to_integer(bin) when is_binary(bin),
    do: if(String.length(bin) > 0, do: String.to_integer(bin), else: nil)

  def to_integer(_), do: nil

  def display_cover_photo(%{cover_photo: %{id: photo_id}}),
    do: %{
      style:
        "background-image: url('#{Picsello.Galleries.Workers.PhotoStorage.path_to_url(photo_id)}')"
    }

  def display_cover_photo(_), do: %{}

  defdelegate preview_url(photo), to: Picsello.Photos
  defdelegate preview_url(photo, opts), to: Picsello.Photos

  def initials_circle(assigns) do
    assigns =
      assigns
      |> Enum.into(%{class: "text-sm text-base-300 bg-gray-100 w-9 h-9 pb-0.5", style: nil})

    ~H"""
      <div style={@style} class={"#{@class} flex flex-col items-center justify-center rounded-full"}><%= Picsello.Accounts.User.initials @user %></div>
    """
  end

  def show_intro?(current_user, intro_id),
    do: current_user |> Onboardings.show_intro?(intro_id) |> inspect()

  def intro(current_user, intro_id) do
    [
      phx_hook: "IntroJS",
      data_intro_show: show_intro?(current_user, intro_id),
      id: intro_id
    ]
  end

  def intro_hints_only(intro_id) do
    [
      phx_hook: "IntroJS",
      id: intro_id
    ]
  end

  def intro_hint(assigns) do
    assigns =
      assigns
      |> Map.put(:rest, Map.drop(assigns, [:content, :class]))
      |> Enum.into(%{class: ""})

    ~H"""
    <span class={"inline-block relative #{@class}"} data-hint={"#{@content}"} data-hintposition="middle-middle"><.icon name="tooltip" class="inline-block w-4 h-4 mr-2 rounded-sm fill-current text-blue-planning-300" /></span>
    """
  end

  def handle_event(
        "intro_js",
        %{"action" => action, "intro_id" => intro_id},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    socket
    |> assign(current_user: Onboardings.save_intro_state(current_user, intro_id, action))
    |> noreply()
  end

  def help_scout_output(current_user, help_scout_id, opts \\ []) do
    %{
      phx_hook: "HelpScout",
      data_id: Application.get_env(:picsello, help_scout_id),
      id: help_scout_id,
      data_email: current_user.email,
      data_name: current_user.name
    }
    |> Map.merge(Enum.into(opts, %{}))
  end

  def shoot_location(%{address: address, location: location}),
    do: address || location |> Atom.to_string() |> dyn_gettext()

  def is_mobile(socket, params) do
    is_mobile = Map.get(params, "is_mobile", get_connect_params(socket)["isMobile"])

    socket
    |> assign(
      is_mobile:
        if(String.valid?(is_mobile), do: String.to_existing_atom(is_mobile), else: is_mobile)
    )
  end

  def get_brand_link_icon("link_" <> _), do: "anchor"
  def get_brand_link_icon(link_id), do: link_id

  def is_custom_brand_link("link_" <> _), do: true
  def is_custom_brand_link(_), do: false

  def remove_cache(user_id, _gallery_id) do
    PicselloWeb.UploaderCache.delete(user_id)
  end

  def stripe_checkout(%{assigns: %{proposal: proposal, job: job}} = socket) do
    payment = PaymentSchedules.unpaid_payment(job)

    case PaymentSchedules.checkout_link(proposal, payment,
           # manually interpolate here to not encode the brackets
           success_url: "#{BookingProposal.url(proposal.id)}?session_id={CHECKOUT_SESSION_ID}",
           cancel_url: BookingProposal.url(proposal.id),
           metadata: %{"paying_for" => payment.id}
         ) do
      {:ok, url} ->
        socket |> redirect(external: url)

      {:error, error} ->
        Logger.error(error)
        socket |> put_flash(:error, "Couldn't redirect to stripe. Please try again")
    end
  end

  def finish_booking(%{assigns: %{proposal: proposal}} = socket) do
    case PaymentSchedules.mark_as_paid(proposal, PicselloWeb.Helpers) do
      {:ok, _} ->
        send(self(), {:update_payment_schedules})
        socket

      {:error, _} ->
        socket |> put_flash(:error, "Couldn't finish booking")
    end
  end

  def format_date_via_type(_, _ \\ "MM DD, YY")

  def format_date_via_type(%DateTime{} = datetime, type),
    do: DateTime.to_date(datetime) |> format_date_via_type(type)

  def format_date_via_type(%Date{} = date, type) do
    case type do
      "MM/DD/YY" ->
        [date.month, date.day, date.year]
        |> Enum.map(&to_string/1)
        |> Enum.map(&String.pad_leading(&1, 2, "0"))
        |> Enum.join("/")

      _ ->
        "#{Timex.month_name(date.month)} #{date.day}, #{date.year}"
    end
  end
end
