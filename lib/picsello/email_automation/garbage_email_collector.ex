defmodule Picsello.EmailAutomation.GarbageEmailCollector do
  @moduledoc false
  use GenServer

  alias Picsello.{
    Organization,
    Accounts.User,
    Repo,
    Job,
    EmailAutomations,
    EmailAutomationSchedules,
    PaymentSchedules,
    Orders,
    EmailAutomation.EmailSchedule
  }

  import Ecto.Query

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{})
  end

  ## Time has been set to 1 days
  def init(state) do
    :timer.send_interval(60_000 * 60 * 24, :collect_garbage_emails)
    {:ok, state}
  end

  ## In this function, we'll collect the garbage emails and send them to the schedule-history tbl
  def handle_info(:collect_garbage_emails, state) do
    from(o in Organization, select: %{id: o.id})
    |> Repo.all()
    |> Enum.each(fn org ->
      user = %User{organization_id: org.id}

      jobs =
        user
        |> Job.for_user()
        |> Job.not_leads()
        |> preload([:shoots, galleries: :orders, client: [organization: :user]])
        |> Repo.all()

      archived_jobs =
        user
        |> Job.for_user()
        |> archived_jobs()

      completed_jobs =
        user
        |> Job.for_user()
        |> Job.not_leads()
        |> completed_jobs()

      stop_garbage_emails(%{jobs: jobs})
      stop_garbage_emails(%{archived_jobs: archived_jobs})
      stop_garbage_emails(%{completed_jobs: completed_jobs})
    end)

    {:noreply, state}
  end

  defp archived_jobs(query) do
    query
    |> Repo.all()
    |> Enum.filter(&(not is_nil(&1.archived_at)))
  end

  defp completed_jobs(query) do
    query
    |> Repo.all()
    |> Enum.filter(&(not is_nil(&1.completed_at)))
  end

  defp stop_garbage_emails(%{jobs: jobs}) do
    Enum.each(jobs, fn job ->
      stop_junk_lead_emails(job)
      stop_shoot_emails(job)
      stop_gallery_emails(job)
    end)
  end

  defp stop_garbage_emails(%{archived_jobs: archived_jobs}) do
    Enum.each(archived_jobs, fn archived_job ->
      stop_archived_emails(archived_job)
    end)
  end

  defp stop_garbage_emails(%{completed_jobs: completed_jobs}) do
    Enum.each(completed_jobs, fn completed_job ->
      stop_completed_emails(completed_job)
    end)
  end

  def stop_job_and_lead_emails(job) do
    states = [
      "pays_retainer",
      "pays_retainer_offline",
      "balance_due",
      "offline_payment",
      "paid_full",
      "paid_offline_full"
    ]

    stop_junk_lead_emails(job)

    if PaymentSchedules.all_paid?(job) do
      pipelines = EmailAutomations.get_pipelines_by_states(states) |> Enum.map(& &1.id)

      email_schedules_query =
        EmailAutomationSchedules.query_get_email_schedule(:job, nil, nil, job.id, pipelines)

      EmailAutomationSchedules.delete_and_insert_schedules_by(
        email_schedules_query,
        :already_paid_full
      )
    end
  end

  defp stop_junk_lead_emails(lead) do
    states = [
      "client_contact",
      "manual_thank_you_lead",
      "manual_booking_proposal_sent",
      "abandoned_emails"
    ]

    pipelines = EmailAutomations.get_pipelines_by_states(states) |> Enum.map(& &1.id)

    email_schedules_query =
      EmailAutomationSchedules.query_get_email_schedule(:job, nil, nil, lead.id, pipelines)

    EmailAutomationSchedules.delete_and_insert_schedules_by(
      email_schedules_query,
      :lead_converted_to_job
    )
  end

  defp stop_archived_emails(job) do
    email_schedules_query = from(es in EmailSchedule, where: es.job_id == ^job.id)

    EmailAutomationSchedules.delete_and_insert_schedules_by(
      email_schedules_query,
      :archived
    )
  end

  defp stop_completed_emails(job) do
    post_shoot_pipeline = EmailAutomations.get_pipeline_by_state(:post_shoot)

    email_schedules_query =
      from(es in EmailSchedule,
        where:
          es.job_id == ^job.id and is_nil(es.gallery_id) and
            es.email_automation_pipeline_id != ^post_shoot_pipeline.id
      )

    EmailAutomationSchedules.delete_and_insert_schedules_by(
      email_schedules_query,
      :completed
    )
  end

  defp stop_shoot_emails(job) do
    states = ["before_shoot", "shoot_thanks"]
    pipelines = EmailAutomations.get_pipelines_by_states(states) |> Enum.map(& &1.id)
    timezone = job.client.organization.user.time_zone
    today = DateTime.utc_now() |> DateTime.shift_zone!(timezone)

    job.shoots
    |> Enum.each(fn shoot ->
      starts_at = shoot.starts_at |> DateTime.shift_zone!(timezone)
      # Add 2 day as buffer
      shoot_start_with_buffer = Date.add(starts_at, 2)

      if Date.diff(shoot_start_with_buffer, today) < 0 do
        email_schedules_query =
          EmailAutomationSchedules.query_get_email_schedule(:shoot, nil, shoot.id, nil, pipelines)

        EmailAutomationSchedules.delete_and_insert_schedules_by(
          email_schedules_query,
          :shoot_starts_at_passed
        )
      end
    end)
  end

  defp stop_gallery_emails(job) do
    states = [
      "manual_gallery_send_link",
      "manual_send_proofing_gallery",
      "manual_send_proofing_gallery_finals"
    ]

    pipelines = EmailAutomations.get_pipelines_by_states(states) |> Enum.map(& &1.id)

    job.galleries
    |> Enum.each(fn gallery ->
      has_any_orders_placed? = Orders.all(gallery.id) |> Enum.any?()

      if has_any_orders_placed? do
        email_schedules_query =
          EmailAutomationSchedules.query_get_email_schedule(
            :gallery,
            gallery.id,
            nil,
            nil,
            pipelines
          )

        EmailAutomationSchedules.delete_and_insert_schedules_by(
          email_schedules_query,
          :gallery_already_shared_because_order_placed
        )
      end
    end)
  end
end
