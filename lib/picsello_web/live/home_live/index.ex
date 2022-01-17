defmodule PicselloWeb.HomeLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Job, Repo, Accounts, Shoot, Accounts.User, ClientMessage}
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_stripe_status()
    |> assign(:page_title, "Work Hub")
    |> assign_counts()
    |> assign_attention_items()
    |> subscribe_inbound_messages()
    |> ok()
  end

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
  def handle_event("intro_js" = event, params, socket),
    do: PicselloWeb.LiveHelpers.handle_event(event, params, socket)

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
             color: "red-sales-300",
             class: "intro-confirmation"
           }},
          {leads_empty?,
           %{
             action: "create-lead",
             title: "Create your first lead",
             body: "Leads are the first step to getting started with Picsello.",
             icon: "three-people",
             button_label: "Create your first lead",
             button_class: "btn-secondary bg-blue-planning-100",
             color: "blue-planning-300",
             class: "intro-first-lead"
           }},
          {stripe_status != :charges_enabled,
           %{
             action: "set-up-stripe",
             title: "Set up Stripe",
             body: "We use Stripe to make payment collection as seamless as possible for you.",
             icon: "money-bags",
             button_label: "Setup your Stripe Account",
             button_class: "btn-secondary bg-blue-planning-100",
             color: "blue-planning-300",
             class: "intro-stripe"
           }},
          {true,
           %{
             action: "",
             title: "Helpful resources",
             body: "Stuck? We have a variety of resources to help you out.",
             icon: "question-mark",
             button_label: "See available resources",
             button_class: "btn-secondary bg-blue-planning-100",
             color: "blue-planning-300",
             class: "intro-resources"
           }}
        ],
        do: item
      )

    socket |> assign(:attention_items, items)
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

  defp assign_stripe_status(%{assigns: %{current_user: current_user}} = socket) do
    socket |> assign(stripe_status: payments().status(current_user))
  end

  defp payments, do: Application.get_env(:picsello, :payments)

  defp subscribe_inbound_messages(%{assigns: %{current_user: current_user}} = socket) do
    Phoenix.PubSub.subscribe(
      Picsello.PubSub,
      "inbound_messages:#{current_user.organization_id}"
    )

    socket
  end
end
