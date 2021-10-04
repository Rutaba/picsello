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

  def time_of_day_greeting(%User{name: name}) do
    "Good Afternoon, #{name}!"
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
        title: "Create a finance account",
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
end
