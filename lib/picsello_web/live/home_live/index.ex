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
    Subscriptions,
    Orders,
    Galleries,
    OrganizationCard,
    Card,
    Utils
  }

  import PicselloWeb.Gettext, only: [ngettext: 3]
  import PicselloWeb.GalleryLive.Index, only: [update_gallery_listing: 1]
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
  def handle_params(
        %{"new_user" => _new_user},
        _uri,
        %{assigns: %{current_user: current_user}} = socket
      ) do
    if show_intro?(current_user, "intro_dashboard_modal") === "true" do
      socket |> PicselloWeb.WelcomeComponent.open(%{close_event: "toggle_welcome_event"})
    else
      socket
    end
    |> noreply()
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
  def handle_event("create-gallery", %{}, socket) do
    socket
    |> open_modal(
      PicselloWeb.GalleryLive.CreateComponent,
      Map.take(socket.assigns, [:current_user])
    )
    |> noreply()
  end

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

  @impl true
  def handle_event(
        "card_status",
        %{"org_card_id" => "", "status" => _},
        socket
      ) do
    socket |> noreply()
  end

  def handle_event(
        "card_status",
        %{"org_card_id" => org_card_id, "status" => status},
        socket
      ) do
    org_card_id = String.to_integer(org_card_id)

    case status do
      "viewed" -> OrganizationCard.viewed!(org_card_id)
      "inactive" -> OrganizationCard.inactive!(org_card_id)
    end

    send(self(), :card_status)

    socket |> noreply()
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
    organization_id = Map.get(current_user, :organization).id
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
      gallery_count:
        Galleries.list_all_galleries_by_organization_query(organization_id)
        |> Repo.all()
        |> Enum.count(),
      galleries_empty?:
        Galleries.list_all_galleries_by_organization_query(organization_id)
        |> Repo.all()
        |> Enum.empty?(),
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
            leads_empty?: leads_empty?,
            current_user: %{organization_id: organization_id} = current_user
          }
        } = socket
      ) do
    subscription = current_user |> Subscriptions.subscription_ending_soon_info()
    orders = get_all_proofing_album_orders(organization_id) |> Map.new(&{&1.id, &1})

    organization_id
    |> OrganizationCard.list()
    |> Enum.concat(Card.list_global_for_dashboard())
    |> Enum.reduce([], fn
      %{card: %{concise_name: "open-user-settings", body: body}} = org_card, acc ->
        data = build_data(subscription)
        acc ++ [add(org_card, Utils.render(body, data))]

      %{card: %{concise_name: "proofing-album-order", body: body}} = org_card, acc ->
        orders
        |> Map.get(org_card.data.order_id)
        |> then(fn
          %{gallery: %{job: %{client: client}}} = order ->
            buttons = build_buttons(socket, org_card.card.buttons, order)

            acc ++ [add(org_card, Utils.render(body, %{"name" => client.name}), buttons)]

          _ ->
            acc
        end)

      org_card, acc ->
        acc ++ [org_card]
    end)
    |> Enum.sort_by(& &1.card.index)
    |> Enum.map(fn %{card: %{concise_name: concise_name}} = org_card ->
      case concise_name do
        card
        when card in [
               "send-confirmation-email",
               "open-user-settings",
               "getting-started-picsello",
               "set-up-stripe",
               "open-billing-portal",
               "missing-payment-method",
               "create-lead",
               "black-friday"
             ] ->
          find_card_action(
            concise_name,
            org_card,
            current_user,
            stripe_status,
            leads_empty?,
            subscription
          )

        _ ->
          {true, org_card}
      end
    end)
    |> then(
      &(socket
        |> assign(
          attention_items: &1,
          should_attention_items_overflow: Enum.count(&1) > 4
        ))
    )
  end

  defp find_card_action(
         concise_name,
         org_card,
         current_user,
         stripe_status,
         leads_empty?,
         subscription
       ) do
    case card_actions(org_card, current_user, stripe_status, leads_empty?, subscription)
         |> Map.fetch(concise_name) do
      {:ok, action} -> action
      :error -> %{"base" => {true, org_card}}
    end
  end

  defp card_actions(org_card, current_user, stripe_status, leads_empty?, subscription),
    do: %{
      "send-confirmation-email" => {!User.confirmed?(current_user), org_card},
      "open-user-settings" => {!subscription.hidden?, org_card},
      "getting-started-picsello" =>
        {Application.get_env(:picsello, :help_scout_id) != nil, org_card},
      "set-up-stripe" => {stripe_status != :charges_enabled, org_card},
      "open-billing-portal" =>
        {Picsello.Invoices.pending_invoices?(current_user.organization_id), org_card},
      "missing-payment-method" =>
        {!Picsello.Subscriptions.subscription_payment_method?(current_user), org_card},
      "create-lead" => {leads_empty?, org_card},
      "black-friday" => {Subscriptions.monthly?(current_user.subscription), org_card}
    }

  defp build_data(subscription) do
    %{
      "days_left" => ngettext("1 day", "%{count} days", Map.get(subscription, :days_left, 0)),
      "subscription_end_at" => Map.get(subscription, :subscription_end_at, nil)
    }
  end

  defp build_buttons(socket, [button_1, button_2], %{
         album: album,
         number: number,
         gallery: gallery
       }) do
    [
      Map.put(
        button_1,
        :link,
        Routes.gallery_photos_index_path(socket, :index, gallery.id, album.id)
      ),
      Map.put(
        button_2,
        :link,
        Routes.gallery_downloads_url(
          socket,
          :download_csv,
          gallery.client_link_hash,
          number
        )
      )
    ]
  end

  defp add(%{card: card} = org_card, body, buttons \\ nil) do
    card = if buttons, do: %{card | buttons: buttons}, else: card

    %{org_card | card: %{card | body: body}}
  end

  def card_buttons(%{concise_name: concise_name, buttons: buttons} = assigns) do
    ~H"""
    <%= case concise_name do %>
      <% "set-up-stripe" -> %>
        <%= live_component PicselloWeb.StripeOnboardingComponent, id: :stripe_onboarding,
          error_class: "text-center",
          class: "#{List.first(buttons).class} text-sm w-full py-2 mt-2",
          current_user: @current_user,
          return_url: Routes.home_url(@socket, :index),
          org_card_id: @org_card_id,
          stripe_status: @stripe_status %>
      <% _ -> %>
      <span class="flex-shrink-0 flex flex-col justify-between" data-status="viewed" id={"#{@org_card_id}"} phx-hook="CardStatus">
        <.card_button buttons={buttons} />
      </span>
    <% end %>
    """
  end

  def card_button(%{buttons: [%{external_link: external_link} = button]} = assigns)
      when not is_nil(external_link) do
    ~H"""
    <.link
    link={external_link}
    class={button.class}
    label={button.label}
    target="_blank"
    rel="noopener noreferrer" />
    """
  end

  def card_button(%{buttons: [%{link: link} = button]} = assigns) when not is_nil(link) do
    ~H"""
    <.link link={link} class={button.class} label={button.label} />
    """
  end

  def card_button(%{buttons: [%{action: action} = button]} = assigns) when not is_nil(action) do
    ~H"""
    <button type="button" phx-click={action} phx-click="sss" class={"#{button.class} text-sm w-full py-2 mt-2"}>
      <%= button.label %>
    </button>
    """
  end

  def card_button(%{buttons: [button_1, button_2]} = assigns) do
    ~H"""
    <div class="flex gap-4">
     <.card_button buttons={[button_1]} />
     <.card_button buttons={[button_2]} />
    </div>
    """
  end

  def link(%{class: class, link: link, label: label} = assigns) do
    assigns = Enum.into(assigns, %{target: "", rel: ""})

    ~H"""
     <a href={link} class={"#{class} text-center text-sm w-full py-2 mt-2"} target={@target} rel={@rel}>
        <%= label %>
      </a>
    """
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
    <div class="fixed inset-0 z-20 flex items-center justify-center bg-black/60">
      <div class="rounded-lg modal sm:max-w-4xl">
        <h1 class="text-3xl font-semibold">Your plan has expired</h1>
        <p class="pt-4">To recover access to <span class="italic">integrated email marketing, easy invoicing, all of your client galleries</span> and much more, please select a plan. Contact us if you have issues.</p>

        <div class="mt-8 grid grid-cols-1 md:grid-cols-2 gap-8">
          <%= for {subscription_plan, i} <- Subscriptions.subscription_plans() |> Enum.with_index() do %>
            <div class="flex items-center justify-between p-4 border rounded-lg">
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

  @impl true
  def handle_info(
        {:close_event, %{event_name: "toggle_welcome_event", link: "gallery"}},
        socket
      ) do
    socket
    |> welcome_modal_state()
    |> push_redirect(to: Routes.gallery_path(socket, :galleries))
    |> noreply()
  end

  @impl true
  def handle_info(
        {:close_event, %{event_name: "toggle_welcome_event", link: "client_booking"}},
        socket
      ) do
    socket
    |> welcome_modal_state()
    |> push_redirect(to: Routes.calendar_booking_events_path(socket, :index))
    |> noreply()
  end

  @impl true
  def handle_info(
        {:close_event, %{event_name: "toggle_welcome_event", link: "demo"}},
        socket
      ) do
    socket
    |> noreply()
  end

  @impl true
  def handle_info(
        {:close_event, %{event_name: "toggle_welcome_event"}},
        socket
      ) do
    socket
    |> welcome_modal_state()
    |> push_patch(to: Routes.home_path(socket, :index), replace: true)
    |> noreply()
  end

  @impl true
  def handle_info({:gallery_created, %{gallery_id: gallery_id}}, socket) do
    socket
    |> PicselloWeb.SuccessComponent.open(%{
      title: "Gallery Created!",
      subtitle: "Hooray! Your gallery has been created. You're now ready to upload photos.",
      success_label: "View gallery",
      success_event: "view-gallery",
      close_label: "Close",
      payload: %{gallery_id: gallery_id}
    })
    |> update_gallery_listing()
    |> noreply()
  end

  def handle_info({:success_event, "view-gallery", %{gallery_id: gallery_id}}, socket) do
    socket
    |> push_redirect(to: Routes.gallery_photographer_index_path(socket, :index, gallery_id))
    |> noreply()
  end

  @impl true
  def handle_info({:stripe_status, status}, socket) do
    socket |> assign(stripe_status: status) |> assign_attention_items() |> noreply()
  end

  def handle_info({:inbound_messages, _message}, %{assigns: %{inbox_count: count}} = socket) do
    socket
    |> assign(:inbox_count, count + 1)
    |> noreply()
  end

  def handle_info(:card_status, socket) do
    socket
    |> assign_attention_items()
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

  defp welcome_modal_state(%{assigns: %{current_user: current_user}} = socket) do
    socket
    |> close_modal
    |> assign(
      current_user:
        Picsello.Onboardings.save_intro_state(current_user, "intro_dashboard_modal", "completed")
    )
  end

  defdelegate get_all_proofing_album_orders(organization_id), to: Orders
end
