defmodule PicselloWeb.HomeLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Job, Repo, Accounts, Accounts.User}
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Work Hub")
    |> assign_counts()
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

  defp assign_counts(%{assigns: %{current_user: current_user}} = socket) do
    lead_count_by_status =
      from(j in Job.for_user(current_user),
        join: s in assoc(j, :job_status),
        where: s.is_lead,
        group_by: s.current_status,
        select: {s.current_status, count(j.id)}
      )
      |> Repo.all()
      |> Enum.into(%{})

    lead_stats =
      for(
        {name, statuses} <- [
          pending: [:not_sent, :sent],
          active: [
            :accepted,
            :signed_with_questionnaire,
            :signed_without_questionnaire,
            :answered
          ]
        ],
        do: {name, statuses |> Enum.map(&Map.get(lead_count_by_status, &1, 0)) |> Enum.sum()}
      )

    socket
    |> assign(
      lead_stats: lead_stats,
      lead_count: lead_stats |> Keyword.values() |> Enum.sum()
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

  def attention_items(current_user) do
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
           color: "orange-warning"
         }},
        {true,
         %{
           action: "",
           title: "Create your first lead",
           body: "Leads are the first step to getting started with Picsello.",
           icon: "three-people",
           button_label: "Create your first lead",
           button_class: "btn-secondary bg-blue-light-primary",
           color: "blue-primary"
         }},
        {true,
         %{
           action: "",
           title: "Set up Stripe",
           body: "We use Stripe to make payment collection as seamless as possible for you.",
           icon: "money-bags",
           button_label: "Setup your Stripe Account",
           button_class: "btn-secondary bg-blue-light-primary",
           color: "blue-primary"
         }},
        {true,
         %{
           action: "",
           title: "Helpful resources",
           body: "Stuck? Need advice? We have a plethora of resources ready for you.",
           icon: "question-mark",
           button_label: "See available resources",
           button_class: "btn-secondary bg-blue-light-primary",
           color: "blue-primary"
         }}
      ],
      do: item
    )
  end

  def card(assigns) do
    attrs = Map.drop(assigns, ~w(class icon color inner_block badge)a)

    ~H"""
    <li class={"relative #{Map.get(assigns, :class)}"} {attrs}>
      <div {testid "badge"} class={classes("absolute -top-2.5 right-5 leading-none w-5 h-5 rounded-full pb-0.5 flex items-center justify-center text-xs", %{"bg-black text-white" => @badge > 0, "bg-gray-300" => @badge == 0})}>
        <%= if @badge > 0, do: @badge %>
      </div>

      <div class={"border hover:border-#{@color} h-full rounded-lg bg-#{@color} overflow-hidden"}>
        <div class="h-full p-5 ml-3 bg-white">
            <h1 class="text-lg font-bold">
            <.icon name={@icon} width="23" height="20" class={"inline-block mr-2 rounded-sm fill-current text-#{@color}"} />

            <%= @title %>
          </h1>

          <%= render_block(@inner_block) %>
        </div>
      </div>
    </li>
    """
  end
end
