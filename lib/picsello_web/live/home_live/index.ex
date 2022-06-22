defmodule PicselloWeb.HomeLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  require Logger

  alias Picsello.{
    Job,
    Payments,
    Repo,
    Accounts,
    Shoot,
    Accounts.User,
    ClientMessage,
    Subscriptions
  }

  import PicselloWeb.Gettext, only: [ngettext: 3]
  import Ecto.Query

  @impl true
  def mount(params, _session, socket) do
    socket
    |> assign_stripe_status()
    |> assign(:page_title, "Work Hub")
    |> assign(:stripe_subscription_status, nil)
    |> assign_counts()
    |> assign_attention_items()
    |> subscribe_inbound_messages()
    |> maybe_show_success_subscription(params)
    |> ok()
  end

  @impl true
  def handle_params(_params, _uri, socket), do: socket |> noreply()

  @impl true
  def handle_event("create-lead", %{}, socket),
    do:
      socket
      |> open_modal(PicselloWeb.JobLive.NewComponent, Map.take(socket.assigns, [:current_user]))
      |> noreply()

  @impl true
  def handle_event("redirect", %{"to" => path}, socket),
    do:
      socket
      |> push_redirect(to: path)
      |> noreply()

  @impl true
  def handle_event("open-user-settings", _, socket),
    do:
      socket
      |> push_redirect(to: Routes.user_settings_path(socket, :edit))
      |> noreply()

  @impl true
  def handle_event(
        "send-confirmation-email",
        %{},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    case Accounts.deliver_user_confirmation_instructions(
           current_user,
           &Routes.user_confirmation_url(socket, :confirm, &1)
         ) do
      {:ok, _} ->
        socket
        |> PicselloWeb.ConfirmationComponent.open(%{
          title: "Email sent",
          subtitle: "The confirmation email has been sent. Please check your inbox."
        })
        |> noreply()

      {:error, _} ->
        socket |> put_flash(:error, "Failed to send email.") |> noreply()
    end
  end

  @impl true
  def handle_event("open-billing-portal", %{}, socket) do
    {:ok, url} =
      Subscriptions.billing_portal_link(
        socket.assigns.current_user,
        Routes.home_url(socket, :index)
      )

    socket |> redirect(external: url) |> noreply()
  end

  @impl true
  def handle_event("intro_js" = event, params, socket),
    do: PicselloWeb.LiveHelpers.handle_event(event, params, socket)

  @impl true
  def handle_event("subscription-checkout", %{"interval" => interval}, socket) do
    case Subscriptions.checkout_link(
           socket.assigns.current_user,
           interval,
           success_url: "#{Routes.home_url(socket, :index)}?session_id={CHECKOUT_SESSION_ID}",
           cancel_url: Routes.home_url(socket, :index)
         ) do
      {:ok, url} ->
        socket |> redirect(external: url) |> noreply()

      {:error, error} ->
        Logger.warning("Error redirecting to Stripe: #{inspect(error)}")
        socket |> put_flash(:error, "Couldn't redirect to Stripe. Please try again") |> noreply()
    end
  end

  defp maybe_show_success_subscription(socket, %{
         "session_id" => "" <> session_id
       }) do
    if connected?(socket),
      do: send(self(), {:stripe_session_id, session_id})

    socket
    |> assign(:stripe_subscription_status, :loading)
  end

  defp maybe_show_success_subscription(socket, %{}), do: socket

  defp assign_counts(%{assigns: %{current_user: current_user}} = socket) do
    job_count_by_status = current_user |> job_count_by_status() |> Repo.all()

    lead_stats =
      for(
        {name, statuses_for_name} <- [
          pending: [:not_sent, :sent],
          active: [
            :accepted,
            :signed_with_questionnaire,
            :signed_without_questionnaire,
            :answered
          ]
        ],
        %{lead?: true, status: status, count: count} <- job_count_by_status,
        reduce: []
      ) do
        acc ->
          count =
            if Enum.member?(statuses_for_name, status) do
              count
            else
              0
            end

          Keyword.update(acc, name, count, &(&1 + count))
      end

    job_count =
      for(
        %{lead?: false, shoot_within_week?: true, count: count, status: status}
        when status != :completed <- job_count_by_status,
        reduce: 0
      ) do
        acc -> acc + count
      end

    socket
    |> assign(
      lead_stats: lead_stats,
      lead_count: lead_stats |> Keyword.values() |> Enum.sum(),
      leads_empty?: Enum.empty?(job_count_by_status),
      jobs_empty?: !Enum.any?(job_count_by_status, &(!&1.lead?)),
      job_count: job_count,
      inbox_count: inbox_count(current_user)
    )
  end

  def time_of_day_greeting(%User{time_zone: time_zone} = user) do
    greeting =
      case DateTime.now(time_zone) do
        {:ok, %{hour: hour}} when hour in 5..11 -> "Good Morning"
        {:ok, %{hour: hour}} when hour in 12..17 -> "Good Afternoon"
        {:ok, %{hour: hour}} when hour in 18..23 -> "Good Evening"
        _ -> "Hello"
      end

    "#{greeting}, #{User.first_name(user)}!"
  end

  def assign_attention_items(
        %{
          assigns: %{
            stripe_status: stripe_status,
            current_user: current_user,
            leads_empty?: leads_empty?
          }
        } = socket
      ) do
    subscription = current_user |> Subscriptions.subscription_ending_soon_info()

    items =
      for(
        {true, item} <- [
          {!User.confirmed?(current_user),
           %{
             action: "send-confirmation-email",
             title: "Confirm your email",
             body: "Check your email to confirm your account before you can start anything.",
             icon: "envelope",
             button_label: "Resend email",
             button_class: "btn-primary",
             external_link: "",
             color: "red-sales-300",
             class: "intro-confirmation border-red-sales-300"
           }},
          {!subscription.hidden?,
           %{
             action: "open-user-settings",
             title: "Subscription ending soon",
             body:
               "You have #{ngettext("1 day", "%{count} days", Map.get(subscription, :days_left, 0))} left before your subscription ends. You will lose access on #{Map.get(subscription, :subscription_end_at, nil)}. Your data will not be deleted and you can resubscribe at any time",
             icon: "clock-filled",
             button_label: "Go to acccount settings",
             button_class: "btn-secondary",
             external_link: "",
             color: "red-sales-300",
             class: "intro-confirmation border-red-sales-300"
           }},
          {Application.get_env(:picsello, :help_scout_id) != nil,
           %{
             action: "external-link",
             title: "Getting started with Picsello guide",
             body:
               "Check out our guide on how best to start running your business with Picsello.",
             icon: "question-mark",
             button_label: "Open guide",
             button_class: "btn-secondary",
             external_link:
               "https://support.picsello.com/article/117-getting-started-with-picsello-guide",
             color: "blue-planning-300",
             class: "intro-help-scout"
           }},
          {stripe_status != :charges_enabled,
           %{
             action: "set-up-stripe",
             title: "Set up Stripe",
             body: "We use Stripe to make payment collection as seamless as possible for you.",
             icon: "money-bags",
             button_label: "Setup your Stripe Account",
             button_class: "btn-secondary",
             external_link: "",
             color: "blue-planning-300",
             class: "intro-stripe"
           }},
          {Picsello.Invoices.pending_invoices?(current_user.organization_id),
           %{
             action: "open-billing-portal",
             title: "Balance(s) Due",
             body:
               "There is an unpaid balance that needs your attention. Please open the Billing Portal to resolve this issue.",
             icon: "money-bags",
             button_label: "Open Billing Portal",
             button_class: "btn-primary",
             external_link: "",
             color: "red-sales-300",
             class: "border-red-sales-300"
           }},
          {true,
           %{
             action: "gallery-links",
             title: "Preview the gallery experience",
             body:
               "We’ve created some clickable previews to see what you and your clients will use without having to book a job first!",
             icon: "add-photos",
             button_label: "Preview client",
             button_class: "btn-secondary",
             external_link: "",
             color: "blue-planning-300",
             class: "intro-resources"
           }},
          {leads_empty?,
           %{
             action: "create-lead",
             title: "Create your first lead",
             body: "Leads are the first step to getting started with Picsello.",
             icon: "three-people",
             button_label: "Create your first lead",
             button_class: "btn-secondary",
             external_link: "",
             color: "blue-planning-300",
             class: "intro-first-lead"
           }},
          {true,
           %{
             action: "external-link",
             title: "Helpful resources",
             body: "Stuck? We have a variety of resources to help you out.",
             icon: "question-mark",
             button_label: "See available resources",
             button_class: "btn-secondary",
             external_link: "https://support.picsello.com/",
             color: "blue-planning-300",
             class: "intro-resources"
           }}
        ],
        do: item
      )

    socket
    |> assign(attention_items: items, should_attention_items_overflow: Enum.count(items) > 4)
  end

  def card(assigns) do
    assigns =
      assigns
      |> Map.put(:attrs, Map.drop(assigns, ~w(class icon color inner_block badge)a))
      |> Enum.into(%{badge: nil, hint_content: nil})

    ~H"""
    <li class={"relative #{Map.get(assigns, :class)}"} {@attrs}>
      <%= if @badge do %>
        <div {testid "badge"} class={classes("absolute -top-2.5 right-5 leading-none w-5 h-5 rounded-full pb-0.5 flex items-center justify-center text-xs", %{"bg-base-300 text-white" => @badge > 0, "bg-gray-300" => @badge == 0})}>
          <%= if @badge > 0, do: @badge %>
        </div>
      <% end %>

      <div class={"border hover:border-#{@color} h-full rounded-lg bg-#{@color} overflow-hidden"}>
        <div class="h-full p-5 ml-3 bg-white">
            <h1 class="text-lg font-bold">
            <.icon name={@icon} width="23" height="20" class={"inline-block mr-2 rounded-sm fill-current text-#{@color}"} />

            <%= @title %> <%= if @hint_content do %><.intro_hint content={@hint_content} /><% end %>
          </h1>

          <%= render_block(@inner_block) %>
        </div>
      </div>
    </li>
    """
  end

  def subscription_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-20 bg-black bg-opacity-60 flex items-center justify-center">
      <div class="modal rounded-lg sm:max-w-4xl">
        <h1 class="text-3xl font-semibold">Your plan has expired</h1>
        <p class="pt-4">To recover access to <span class="italic">integrated email marketing, easy invoicing, all of your client galleries</span> and much more, please select a plan. Contact us if you have issues.</p>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-8 mt-8">
          <%= for {subscription_plan, i} <- Subscriptions.subscription_plans() |> Enum.with_index() do %>
            <div class="border rounded-lg p-4 flex items-center justify-between">
              <p class="text-3xl font-semibold"> <%= subscription_plan.price |> Money.to_string(fractional_unit: false) %>/<%= subscription_plan.recurring_interval %></p>
              <button class={if i == 0, do: "btn-primary", else: "btn-secondary"} type="button" phx-click="subscription-checkout" phx-value-interval={subscription_plan.recurring_interval}>
                Select this plan
              </button>
            </div>
          <% end %>
        </div>

        <div class="flex mt-6">
          <%= link("Logout", to: Routes.user_session_path(@socket, :delete), method: :delete, class: "underline ml-auto") %>
        </div>
      </div>
    </div>
    """
  end

  defp job_count_by_status(user) do
    now = DateTime.utc_now()
    a_week_from_now = DateTime.add(now, 7 * 24 * 60 * 60)

    from(job in Job.for_user(user),
      join: status in assoc(job, :job_status),
      left_join:
        shoots in subquery(
          from(shoots in Shoot,
            group_by: shoots.job_id,
            select: %{
              shoot_within_week?:
                min(shoots.starts_at) >= ^now and min(shoots.starts_at) < ^a_week_from_now,
              job_id: shoots.job_id
            }
          )
        ),
      on: shoots.job_id == job.id,
      group_by: [status.current_status, status.is_lead, shoots.shoot_within_week?],
      select: %{
        lead?: status.is_lead,
        status: status.current_status,
        count: count(job.id),
        shoot_within_week?: coalesce(shoots.shoot_within_week?, false)
      }
    )
  end

  defp inbox_count(user) do
    Job.for_user(user)
    |> ClientMessage.unread_messages()
    |> Repo.aggregate(:count)
  end

  def handle_info({:stripe_status, status}, socket) do
    socket |> assign(stripe_status: status) |> assign_attention_items() |> noreply()
  end

  def handle_info({:inbound_messages, _message}, %{assigns: %{inbox_count: count}} = socket) do
    socket
    |> assign(:inbox_count, count + 1)
    |> noreply()
  end

  def handle_info({:stripe_session_id, stripe_session_id}, socket) do
    case Subscriptions.handle_subscription_by_session_id(stripe_session_id) do
      :ok ->
        socket
        |> assign(:stripe_subscription_status, :success)
        |> PicselloWeb.ConfirmationComponent.open(%{
          title: "You have subscribed to Picsello",
          subtitle:
            "We’re excited to have join Picsello. You can always manage your subscription in account settings. If you have any trouble, contact support.",
          close_label: "Close",
          close_class: "btn-primary"
        })
        # clear the session_id param
        |> push_patch(to: Routes.home_path(socket, :index), replace: true)
        |> noreply()

      _ ->
        socket
        |> put_flash(:error, "Couldn't fetch your Stripe session. Please try again")
        |> noreply()
    end
  end

  defp assign_stripe_status(%{assigns: %{current_user: current_user}} = socket) do
    socket |> assign(stripe_status: Payments.status(current_user))
  end

  defp subscribe_inbound_messages(%{assigns: %{current_user: current_user}} = socket) do
    Phoenix.PubSub.subscribe(
      Picsello.PubSub,
      "inbound_messages:#{current_user.organization_id}"
    )

    socket
  end
end
