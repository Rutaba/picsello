defmodule Picsello.Workers.ScheduleAutomationEmail do
  @moduledoc "Background job to send scheduled emails"
  require Logger

  use Oban.Worker,
    unique: [period: :infinity, states: ~w[available scheduled executing retryable]a]

  alias Picsello.{
    EmailAutomations,
    EmailAutomationSchedules,
    ClientMessage,
    Organization,
    Galleries.Gallery,
    Job,
    Repo
  }

  alias PicselloWeb.EmailAutomationLive.Shared
  @impl Oban.Worker
  def perform(_) do
    get_all_organizations()
    |> Enum.chunk_every(10)
    |> Enum.each(&send_emails_by_organizations(&1))
    # |> Task.async_stream(&send_emails_by_organizations(&1),
    #   max_concurrency: System.schedulers_online() * 3,
    #   timeout: 360_000
    # )
    # |> Stream.run()

    Logger.info("------------Email Automation Schedule Completed")
    :ok
  end

  defp send_emails_by_organizations(ids) do
    get_all_emails(ids)
    |> Enum.map(fn job_pipeline ->
      try do
        gallery = EmailAutomations.get_gallery(job_pipeline.gallery_id)
        job = EmailAutomations.get_job(job_pipeline.job_id)

        job = if is_nil(gallery), do: job, else: gallery.job
        send_email_by(job, gallery, job_pipeline)
      rescue
        error ->
          message = "Error sending email #{inspect(%{pipeline: job_pipeline, error: error})}"
          if Mix.env() == :prod, do: Sentry.capture_message(message, stacktrace: __STACKTRACE__)
          Logger.error(message)
      end
    end)
  end

  defp send_email_by(_job, nil, %{state: state})
       when state in [
              :order_arrived,
              :order_delayed,
              :order_shipped,
              :digitals_ready_download,
              :order_confirmation_digital_physical,
              :order_confirmation_digital,
              :order_confirmation_physical,
              :after_gallery_send_feedback,
              :gallery_password_changed,
              :gallery_expiration_soon,
              :cart_abandoned,
              :manual_gallery_send_link,
              :manual_send_proofing_gallery,
              :manual_send_proofing_gallery_finals
            ],
       do: Logger.info("Gallery is not active")

  defp send_email_by(job, gallery, job_pipeline) do
    subjects = get_subjects_for_job_pipeline(job_pipeline.emails)
    state = job_pipeline.state

    type =
      job_pipeline.emails
      |> List.first()
      |> Map.get(:email_automation_pipeline)
      |> Map.get(:email_automation_category)
      |> Map.get(:type)

    if is_job_emails?(job) and is_gallery_active?(gallery) do
      # Each pipeline emails subjects resolve variables
      subjects_resolve = EmailAutomations.resolve_all_subjects(job, gallery, type, subjects)

      # Check client reply for any email of current pipeline
      is_reply =
        if state in [:client_contact, :manual_thank_you_lead, :manual_booking_proposal_sent] do
          is_reply_receive!(job, subjects_resolve)
        else
          false
        end

      # This condition only run when no reply recieve from any email for that job & pipeline
      if !is_reply do
        send_email_each_pipeline(job_pipeline, job, gallery)
      end
    end
  end

  def get_all_emails(organizations) do
    EmailAutomationSchedules.get_all_emails_schedules(organizations)
    |> Enum.group_by(&group_key/1)
    |> Enum.map(fn {{job_id, gallery_id, pipeline_id}, emails} ->
      state = List.first(emails) |> Map.get(:email_automation_pipeline) |> Map.get(:state)

      %{
        job_id: job_id,
        gallery_id: gallery_id,
        pipeline_id: pipeline_id,
        state: state,
        emails: Shared.sort_emails(emails, state)
      }
    end)
  end

  defp send_email_each_pipeline(job_pipeline, job, gallery) do
    # Get first email from pipeline which is not sent
    email_schedules =
      job_pipeline.emails |> Enum.filter(fn email -> is_nil(email.reminded_at) end)

    Enum.each(email_schedules, fn schedule ->
      state = schedule.email_automation_pipeline.state
      send_email_by_state(state, job_pipeline.pipeline_id, schedule, job, gallery, nil)
    end)
  end

  defp send_email_by_state(state, pipeline_id, schedule, job, gallery, _order)
       when state in [
              :order_arrived,
              :order_delayed,
              :order_shipped,
              :digitals_ready_download,
              :order_confirmation_digital_physical,
              :order_confirmation_digital,
              :order_confirmation_physical
            ] do
    order = EmailAutomations.get_order(schedule.order_id)

    send_email(state, pipeline_id, schedule, job, gallery, order)
  end

  defp send_email_by_state(state, pipeline_id, schedule, job, gallery, order) do
    send_email(state, pipeline_id, schedule, job, gallery, order)
  end

  defp send_email(state, pipeline_id, schedule, job, gallery, order) do
    type = schedule.email_automation_pipeline.email_automation_category.type
    type = if order, do: :order, else: type
    state = if is_atom(state), do: state, else: String.to_atom(state)

    job_date_time =
      Shared.fetch_date_for_state_maybe_manual(state, schedule, pipeline_id, job, gallery, order)

    is_send_time = is_email_send_time(job_date_time, state, schedule.total_hours)

    if is_send_time and is_nil(schedule.reminded_at) and is_nil(schedule.stopped_at) do
      send_email_task(type, state, schedule, job, gallery, order)
    end
  end

  defp group_key(email_schedule) do
    {email_schedule.job_id, email_schedule.gallery_id,
     email_schedule.email_automation_pipeline_id}
  end

  defp is_email_send_time(nil, _state, _total_hours), do: false

  defp is_email_send_time(_submit_time, state, _total_hours)
       when state in [
              :shoot_thanks,
              :post_shoot,
              :before_shoot,
              :gallery_expiration_soon,
              :after_gallery_send_feedback
            ],
       do: true

  defp is_email_send_time(submit_time, _state, total_hours) do
    %{sign: sign} = EmailAutomations.explode_hours(total_hours)
    {:ok, current_time} = DateTime.now("Etc/UTC")
    diff_seconds = DateTime.diff(current_time, submit_time, :second)
    hours = div(diff_seconds, 3600)
    before_after_send_time(sign, hours, abs(total_hours))
  end

  defp before_after_send_time(_sign, hours, 0) when hours > 0, do: true

  defp before_after_send_time("+", hours, total_hours),
    do: if(hours >= total_hours, do: true, else: false)

  defp before_after_send_time("-", hours, total_hours),
    do: if(hours <= total_hours, do: true, else: false)

  defp get_subjects_for_job_pipeline(emails) do
    emails
    |> Enum.map(& &1.subject_template)
  end

  defp is_reply_receive!(nil, _subjects), do: false

  defp is_reply_receive!(job, subjects) do
    ClientMessage.get_client_messages(job, subjects)
    |> Enum.count() > 0
  end

  defp send_email_task(type, state, schedule, job, gallery, order) do
    schema =
      case type do
        :gallery -> gallery
        :order -> order
        _ -> job
      end

    send_email_task = EmailAutomations.send_now_email(type, schedule, schema, state)

    case send_email_task do
      {:ok, _result} ->
        Logger.info(
          "Email #{schedule.name} sent at #{DateTime.truncate(DateTime.utc_now(), :second)}"
        )

      result when result in ["ok", :ok] ->
        Logger.info(
          "Email #{schedule.name} sent at #{DateTime.truncate(DateTime.utc_now(), :second)}"
        )

      error ->
        Logger.error("Email #{schedule.name} #{error}")
    end
  end

  defp get_all_organizations() do
    Repo.all(Organization) |> Enum.map(& &1.id)
  end

  defp is_job_emails?(%Job{
         job_status: %{is_lead: true},
         booking_event_id: booking_event_id,
         archived_at: archived_at
       })
       when not is_nil(booking_event_id) and not is_nil(archived_at),
       do: true

  defp is_job_emails?(%Job{archived_at: nil}), do: true
  defp is_job_emails?(_), do: false

  defp is_gallery_active?(nil), do: true
  defp is_gallery_active?(%Gallery{status: :active}), do: true
  defp is_gallery_active?(_), do: false
end
