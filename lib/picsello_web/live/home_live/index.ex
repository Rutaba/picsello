defmodule PicselloWeb.HomeLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.{Job, Repo, Accounts.User}
  require Ecto.Query

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

  defp assign_counts(%{assigns: %{current_user: current_user}} = socket) do
    [lead_count, job_count] =
      current_user
      |> Job.for_user()
      |> Ecto.Query.preload([:booking_proposals, :job_status])
      |> Repo.all()
      |> Enum.split_with(&Job.lead?/1)
      |> Tuple.to_list()
      |> Enum.map(&Enum.count/1)

    socket |> assign(lead_count: lead_count, job_count: job_count)
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

  def attention_items(_socket) do
    [
      %{
        title: "Confirm your email",
        body: "Check your email to confirm your account before you can start anything.",
        icon: "envelope",
        button_label: "Resend email",
        button_class: "btn-primary",
        color: "orange-warning"
      },
      %{
        title: "Create your first lead",
        body: "Leads are the first step to getting started with Picsello.",
        icon: "three-people",
        button_label: "Create your first lead",
        button_class: "btn-secondary bg-blue-light-primary",
        color: "blue-primary"
      },
      %{
        title: "Set up Stripe",
        body: "We use Stripe to make payment collection as seamless as possible for you.",
        icon: "money-bags",
        button_label: "Setup your Stripe Account",
        button_class: "btn-secondary bg-blue-light-primary",
        color: "blue-primary"
      },
      %{
        title: "Helpful resources",
        body: "Stuck? Need advice? We have a plethora of resources ready for you.",
        icon: "question-mark",
        button_label: "See available resources",
        button_class: "btn-secondary bg-blue-light-primary",
        color: "blue-primary"
      }
    ]
    |> Enum.take(4)
  end

  def card(assigns) do
    attrs = Map.drop(assigns, ~w(class icon color inner_block badge)a)

    ~H"""
    <li class={"relative #{Map.get(assigns, :class)}"} {attrs}>
      <div class={classes("absolute -top-2.5 right-5 leading-none w-5 h-5 rounded-full pb-0.5 flex items-center justify-center text-sm", %{"bg-black text-white" => @badge > 0, "bg-gray-300" => @badge == 0})}>
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
