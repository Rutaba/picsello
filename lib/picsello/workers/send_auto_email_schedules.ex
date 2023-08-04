defmodule Picsello.Workers.ScheduleAutomationEmail do
  @moduledoc "Background job to send scheduled emails"
  require Logger

  use Oban.Worker,
    unique: [period: :infinity, states: ~w[available scheduled executing retryable]a]

  alias Picsello.{
    EmailAutomations,
    EmailAutomationSchedules,
    Orders,
    Galleries,
    ClientMessage,
    Organization,
    Repo
  }

  alias PicselloWeb.EmailAutomationLive.Shared

  def perform(_) do
    get_all_organizations()
    |> Enum.chunk_every(2)
    |> Enum.map(fn organizations ->
      get_all_emails(organizations)
      |> Enum.map(fn job_pipeline ->
        job_id = job_pipeline.job_id
        gallery_id = job_pipeline.gallery_id
        state = job_pipeline.state

        gallery_task = Task.async(fn -> get_gallery(gallery_id) end)
        gallery = Task.await(gallery_task)

        job_task = Task.async(fn -> EmailAutomations.get_job(job_id) end)

        type =
          job_pipeline.emails
          |> List.first()
          |> Map.get(:email_automation_pipeline)
          |> Map.get(:email_automation_category)
          |> Map.get(:type)

        Logger.info("[email category] #{type}")

        subjects_task = Task.async(fn -> get_subjects_for_job_pipeline(job_pipeline.emails) end)

        job = Task.await(job_task)
        job = if is_nil(gallery_id), do: job, else: gallery.job

        subjects = Task.await(subjects_task)
        Logger.info("Email Subjects #{subjects}")

        # Each pipeline emails subjects resolve variables
        subjects_resolve = EmailAutomations.resolve_all_subjects(job, gallery, type, subjects)
        Logger.info("Email Subjects Resolve [#{subjects_resolve}]")

        # Check client reply for any email of current pipeline
        is_reply =
          if state in [
               :shoot_thanks,
               :post_shoot,
               :before_shoot,
               :gallery_expiration_soon,
               :paid_full,
               :paid_offline_full,
               :balance_due,
               :offline_payment,
               :digitals_ready_download
             ] do
            false
          else
            is_reply_receive!(job, subjects_resolve)
          end

        Logger.info(
          "Reply of any email from client for job #{job_id} and pipeline_id #{job_pipeline.pipeline_id}"
        )

        # This condition only run when no reply recieve from any email for that job & pipeline
        if !is_reply and is_nil(job.archived_at) do
          send_email_each_pipeline(job_pipeline, job, gallery)
        end
      end)
    end)

    :ok
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
    email_schedule = job_pipeline.emails |> Enum.find(fn email -> is_nil(email.reminded_at) end)

    if email_schedule do
      state = email_schedule.email_automation_pipeline.state
      send_email_by_state(state, job_pipeline.pipeline_id, email_schedule, job, gallery, nil)
    end
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
    order =
      Orders.get_order(schedule.order_id)
      |> Repo.preload(gallery: :job)

    send_email(state, pipeline_id, schedule, job, gallery, order)
  end

  defp send_email_by_state(state, pipeline_id, schedule, job, gallery, order) do
    send_email(state, pipeline_id, schedule, job, gallery, order)
  end

  defp send_email(state, pipeline_id, schedule, job, gallery, order) do
    type = schedule.email_automation_pipeline.email_automation_category.type

    Logger.info("state #{state}")

    job_date_time =
      Shared.fetch_date_for_state_maybe_manual(state, schedule, pipeline_id, job, gallery, order)

    Logger.info("Job date time for state #{state} #{job_date_time}")

    is_send_time =
      if state in [:shoot_thanks, :post_shoot, :before_shoot, :gallery_expiration_soon] and
           not is_nil(job_date_time) do
        true
      else
        is_email_send_time(job_date_time, schedule.total_hours)
      end

    Logger.info("Time to send email #{is_send_time}")

    if is_send_time and is_nil(schedule.reminded_at) and !schedule.is_stopped do
      schema =
        case type do
          :gallery -> if is_nil(order), do: gallery, else: order
          _ -> job
        end

      send_email_task =
        Task.async(fn -> EmailAutomations.send_now_email(type, schedule, schema, state) end)

      case Task.await(send_email_task) do
        {:ok, _result} ->
          Logger.info(
            "Email #{schedule.name} sent at #{DateTime.truncate(DateTime.utc_now(), :second)}"
          )

        error ->
          Logger.error("Email #{schedule.name} #{error}")
      end
    end
  end

  defp get_gallery(nil), do: nil
  defp get_gallery(id), do: Galleries.get_gallery!(id) |> Repo.preload([:albums, job: :client])

  defp group_key(email_schedule) do
    if email_schedule.job_id != nil do
      {email_schedule.job_id, nil, email_schedule.email_automation_pipeline_id}
    else
      {nil, email_schedule.gallery_id, email_schedule.email_automation_pipeline_id}
    end
  end

  defp is_email_send_time(nil, _total_hours), do: false

  defp is_email_send_time(submit_time, total_hours) do
    %{sign: sign} = Shared.explode_hours(total_hours)
    {:ok, current_time} = DateTime.now("Etc/UTC")
    diff_seconds = DateTime.diff(current_time, submit_time, :second)
    hours = div(diff_seconds, 3600)
    before_after_send_time(sign, hours, abs(total_hours))
  end

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

  defp get_all_organizations() do
    Repo.all(Organization) |> Enum.map(& &1.id)
  end
end
