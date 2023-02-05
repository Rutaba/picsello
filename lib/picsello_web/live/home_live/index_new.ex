defmodule PicselloWeb.HomeLive.IndexNew do
  @moduledoc false
  use PicselloWeb, :live_view
  require Logger

  alias Picsello.{
    Subscriptions,
    Marketing,
    ClientMessage,
    Job,
    Repo
  }

  alias PicselloWeb.{
    Live.ClientLive.ClientFormComponent,
    Live.Marketing.NewCampaignComponent,
    JobLive.ImportWizard,
    QuestionnaireFormComponent
  }

  import PicselloWeb.HomeLive.Shared
  import Ecto.Query, only: [from: 2, subquery: 1]

  @impl true
  def mount(params, _session, socket) do
    socket
    |> assign_stripe_status()
    |> assign(:page_title, "Work Hub")
    |> assign(:stripe_subscription_status, nil)
    |> assign_counts()
    |> assign_attention_items()
    |> assign(:tabs, tabs_list(socket))
    |> assign(:tab_active, "todo")
    |> subscribe_inbound_messages()
    |> assign_inbox_threads()
    |> maybe_show_success_subscription(params)
    |> ok()
  end

  @impl true
  def handle_event("create-booking-event", _, socket),
    do:
      socket
      |> push_redirect(to: Routes.calendar_booking_events_path(socket, :new))
      |> noreply()

  @impl true
  def handle_event("add-client", _, socket),
    do:
      socket
      |> ClientFormComponent.open()
      |> noreply()

  @impl true
  def handle_event("add-package", %{}, socket),
    do:
      socket
      |> push_redirect(to: Routes.package_templates_path(socket, :new))
      |> noreply()

  @impl true
  def handle_event(
        "create-questionnaire",
        %{},
        %{assigns: %{current_user: %{organization_id: organization_id}} = assigns} = socket
      ) do
    assigns =
      Map.merge(assigns, %{
        questionnaire: %Picsello.Questionnaire{organization_id: organization_id}
      })

    socket
    |> QuestionnaireFormComponent.open(
      Map.merge(Map.take(assigns, [:questionnaire, :current_user]), %{state: :create})
    )
    |> noreply()
  end

  @impl true
  def handle_event("import-job", %{}, socket),
    do:
      socket
      |> open_modal(ImportWizard, Map.take(socket.assigns, [:current_user]))
      |> noreply()

  @impl true
  def handle_event("view-help", _, socket),
    do:
      socket
      |> redirect(external: "https://support.picsello.com")
      |> noreply()

  @impl true
  def handle_event("create-marketing-email", _, socket),
    do:
      socket
      |> NewCampaignComponent.open()
      |> noreply()

  @impl true
  def handle_event("change-tab", %{"tab" => tab}, socket) do
    socket
    |> assign(:tab_active, tab)
    |> noreply()
  end

  @impl true
  def handle_event("open-thread", %{"id" => id}, socket) do
    socket
    |> push_redirect(to: Routes.inbox_path(socket, :show, id))
    |> noreply()
  end

  # This is temporary as the other tabs get built out
  @impl true
  def handle_event("redirect", %{"to" => to}, socket) do
    socket
    |> push_redirect(to: to)
    |> noreply()
  end

  @impl true
  def handle_info(
        {:load_template_preview, component, body_html},
        %{assigns: %{current_user: current_user, modal_pid: modal_pid}} = socket
      ) do
    template_preview = Marketing.template_preview(current_user, body_html)

    send_update(
      modal_pid,
      component,
      id: component,
      template_preview: template_preview
    )

    socket
    |> noreply()
  end

  @impl true
  def handle_info({:update, %{questionnaire: _questionnaire}}, socket) do
    socket
    |> put_flash(:success, "Questionnaire saved")
    |> push_redirect(to: Routes.questionnaires_index_path(socket, :index))
    |> noreply()
  end

  @impl true
  defdelegate handle_params(name, params, socket), to: PicselloWeb.HomeLive.Shared

  @impl true
  defdelegate handle_event(name, params, socket), to: PicselloWeb.HomeLive.Shared

  @impl true
  defdelegate handle_info(message, socket), to: PicselloWeb.HomeLive.Shared

  def tabs_nav(assigns) do
    ~H"""
    <ul class="flex gap-6 mb-6">
      <%= for {true, %{name: name, action: action, concise_name: concise_name, redirect_route: redirect_route}} <- @tabs do %>
        <li class={classes("text-blue-planning-300 font-bold text-lg border-b-4 transition-all", %{"opacity-100 border-b-blue-planning-300" => @tab_active === concise_name, "opacity-40 border-b-transparent hover:opacity-100" => @tab_active !== concise_name})}>
          <button type="button" phx-click={action} phx-value-tab={concise_name} phx-value-to={redirect_route}><%= name %></button>
        </li>
      <% end %>
    </ul>
    """
  end

  def tabs_content(
        %{
          assigns: %{
            attention_items: attention_items,
            should_attention_items_overflow: should_attention_items_overflow,
            current_user: current_user
          }
        } = assigns
      ) do
    ~H"""
    <div>
      <%= case attention_items do %>
        <% [] -> %>
          <h6 class="flex items-center font-bold text-blue-planning-300"><.icon name="confetti-welcome" class="inline-block w-8 h-8 text-blue-planning-300" /> You're all caught up!</h6>
        <% items -> %>
          <ul class={classes("flex overflow-auto intro-next-up", %{"xl:overflow-none" => !should_attention_items_overflow })}>
            <%= for {true, %{card: %{title: title, body: body, icon: icon, buttons: buttons, concise_name: concise_name, color: color, class: class}} = org_card} <- items do %>
            <li {testid("attention-item")} class={classes("attention-item flex-shrink-0 flex flex-col justify-between relative max-w-sm w-3/4 p-5 cursor-pointer mr-4 border rounded-lg #{class} bg-white border-gray-250", %{"xl:flex-1" => !should_attention_items_overflow})}>
              <%= if org_card.status == :viewed and concise_name != "black-friday" do %>
                <div class="flex justify-between absolute w-full">
                  <span></span>
                  <span class="sm:pr-[30px] pr-[25px]" phx-click="card_status" phx-value-org_card_id={org_card.id} phx-value-status="inactive">
                    <.icon name="close-x" class="mt-[-7px] w-3 h-3 stroke-current stroke-2 base-250" />
                  </span>
                </div>
              <% end %>
              <div>
                <div class="flex">
                  <.icon name={icon} width="23" height="20" class={"block mr-2 mt-1 rounded-sm fill-current text-#{color}"} />
                  <h1 class="text-lg font-bold"><%= title %></h1>
                </div>

                <p class="my-2 text-sm"><%= body %></p>
              </div>

              <.card_buttons {assigns} current_user={current_user} socket={@socket} concise_name={concise_name} org_card_id={org_card.id} buttons={buttons} />
            </li>
            <% end %>
          </ul>
      <% end %>
    </div>
    """
  end

  def tabs_content(assigns) do
    ~H"""
    <div></div>
    """
  end

  def action_item(assigns) do
    assigns =
      Enum.into(assigns, %{
        button_text: nil,
        button_action: nil,
        button_icon: nil
      })

    ~H"""
    <button title={@button_text} type="button" phx-click={@button_action} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
      <.icon name={@button_icon} class="inline-block w-4 h-4 mr-3 text-blue-planning-300" />
      <%= @button_text %>
    </button>
    """
  end

  def dashboard_main_card(assigns) do
    assigns =
      Enum.into(assigns, %{
        title: nil,
        inner_block: nil,
        inner_block_classes: nil,
        button_text: nil,
        button_action: nil,
        link_text: nil,
        link_action: nil,
        link_value: nil,
        notification_count: nil,
        redirect_route: nil
      })

    ~H"""
    <div class="rounded-lg bg-white p-6 grow flex flex-col items-start">
      <div class="flex justify-between items-center mb-2 w-full gap-6">
        <h3 class="text-2xl font-bold flex items-center gap-2">
          <%= @title %>
          <.notification_bubble notification_count={@notification_count} />
        </h3>
        <%= if @button_action && @button_text do %>
          <button class="btn-tertiary py-2 px-4 mt-2 md:mt-0 flex-wrap whitespace-nowrap flex-shrink-0" type="button" phx-click={@button_action}><%= @button_text %></button>
        <% end %>
      </div>
      <div class={"mb-2 #{@inner_block_classes}"}>
        <%= render_block(@inner_block) %>
      </div>
      <%= if @link_action && @link_text do %>
        <button class="underline text-blue-planning-300 mt-auto inline-block" type="button" phx-click={@link_action} phx-value-tab={@link_value} phx-value-to={@redirect_route}><%= @link_text %></button>
      <% end %>
    </div>
    """
  end

  def notification_bubble(assigns) do
    assigns =
      Enum.into(assigns, %{
        notification_count: nil,
        classes: nil
      })

    ~H"""
    <%= if @notification_count && @notification_count !== 0 do %>
      <span class={"text-xs bg-red-sales-300 text-white w-5 h-5 leading-none rounded-full flex items-center justify-center pb-0.5 #{@classes}"}><%= @notification_count %></span>
    <% end %>
    """
  end

  def thread_card(assigns) do
    ~H"""
    <div {testid("thread-card")} phx-click="open-thread" phx-value-id={@id} class="flex justify-between border-b cursor-pointer first:pt-0 py-3">
      <div class="">
        <div class="flex items-center">
          <div class="text-xl line-clamp-1 font-bold"><%= @title %></div>
          <%= if @unread do %>
            <span {testid("new-badge")} class="mx-4 px-2 py-0.5 text-xs rounded bg-blue-planning-300 text-white">New</span>
          <% end %>
        </div>
        <div class="line-clamp-1 font-semibold py-0.5 text-base-250"><%= @subtitle %></div>
        <div class="line-clamp-1 text-base-250"><%= @message %></div>
      </div>
      <div class="relative flex flex-shrink-0">
        <%= @date %>
        <.icon name="forth" class="sm:hidden absolute top-1.5 -right-6 w-4 h-4 stroke-current text-base-300 stroke-2" />
      </div>
    </div>
    """
  end

  defp assign_inbox_threads(%{assigns: %{current_user: current_user}} = socket) do
    job_query = Job.for_user(current_user) |> ClientMessage.unread_messages()

    message_query =
      from(message in job_query,
        distinct: message.job_id,
        order_by: [desc: message.inserted_at]
      )

    inbox_threads =
      from(message in subquery(message_query), order_by: [desc: message.inserted_at], limit: 3)
      |> Repo.all()
      |> Repo.preload(job: :client)
      |> Enum.map(fn message ->
        %{
          id: message.job_id,
          title: message.job.client.name,
          subtitle: Job.name(message.job),
          message: message.body_text,
          date: strftime(current_user.time_zone, message.inserted_at, "%-m/%-d/%y")
        }
      end)

    socket
    |> assign(:inbox_threads, inbox_threads)
  end

  defp tabs_list(socket) do
    [
      {true,
       %{
         name: "To do",
         concise_name: "todo",
         action: "change-tab",
         redirect_route: nil,
         notification_count: nil
       }},
      {false,
       %{
         name: "Finish Setup",
         concise_name: "finish-setup",
         action: "change-tab",
         redirect_route: nil,
         notification_count: nil
       }},
      {true,
       %{
         name: "Clients",
         concise_name: "clients",
         action: "redirect",
         redirect_route: Routes.clients_path(socket, :index),
         notification_count: nil
       }},
      {true,
       %{
         name: "Leads",
         concise_name: "leads",
         action: "redirect",
         redirect_route: Routes.job_path(socket, :leads),
         notification_count: nil
       }},
      {true,
       %{
         name: "Jobs",
         concise_name: "jobs",
         action: "redirect",
         redirect_route: Routes.job_path(socket, :jobs),
         notification_count: nil
       }},
      {true,
       %{
         name: "Galleries",
         concise_name: "galleries",
         action: "redirect",
         redirect_route: Routes.gallery_path(socket, :galleries),
         notification_count: nil
       }},
      {true,
       %{
         name: "Booking Events",
         concise_name: "booking-events",
         action: "redirect",
         redirect_route: Routes.calendar_booking_events_path(socket, :index),
         notification_count: nil
       }},
      {true,
       %{
         name: "Packages",
         concise_name: "packages",
         action: "redirect",
         redirect_route: Routes.package_templates_path(socket, :index),
         notification_count: nil
       }}
    ]
  end
end
