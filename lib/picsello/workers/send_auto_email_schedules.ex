defmodule Picsello.Workers.ScheduleAutomationEmail do
  @moduledoc "Background job to send scheduled emails"
  require Logger

  use Oban.Worker,
    unique: [period: :infinity, states: ~w[available scheduled executing retryable]a]

  alias Picsello.{EmailAutomations, Galleries, Repo}

  def perform(_) do
    get_all_emails()
    |> Enum.map(fn job_pipeline ->
      job_id = job_pipeline.job_id
      gallery_id = job_pipeline.gallery_id

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

      subjects_task =
        Task.async(fn -> EmailAutomations.get_subjects_for_job_pipeline(job_pipeline.emails) end)

      job = Task.await(job_task)
      job = if is_nil(gallery_id), do: job, else: gallery.job

      subjects = Task.await(subjects_task)
      Logger.info("Email Subjects #{subjects}")

      # Each pipeline emails subjects resolve variables
      subjects_resolve = EmailAutomations.resolve_all_subjects(job, gallery, type, subjects)
      Logger.info("Email Subjects Resolve [#{subjects_resolve}]")

      # Check client reply for any email of current pipeline
      is_reply = EmailAutomations.is_reply_receive!(job, subjects_resolve)

      Logger.info(
        "Reply of any email from client for job #{job_id} and pipeline_id #{job_pipeline.pipeline_id}"
      )

      # This condition only run when no reply recieve from any email for that job & pipeline
      if !is_reply do
        send_email_each_pipeline(job_pipeline, job, gallery)
      end
    end)

    :ok
  end

  def get_all_emails() do
    EmailAutomations.get_all_emails_schedules()
    |> Enum.group_by(&group_key/1)
    |> Enum.map(fn {{job_id, gallery_id, pipeline_id}, emails} ->
      %{
        job_id: job_id,
        gallery_id: gallery_id,
        pipeline_id: pipeline_id,
        emails: emails
      }
    end)
  end

  defp send_email_each_pipeline(job_pipeline, job, gallery) do
    Enum.map(job_pipeline.emails, fn schedule ->
      state = schedule.email_automation_pipeline.state
      type = schedule.email_automation_pipeline.email_automation_category.type
      job_date_time = EmailAutomations.fetch_date_for_state(state, job)
      Logger.info("Job date time for state #{state} #{job_date_time}")

      is_send_time = EmailAutomations.is_email_send_time(job_date_time, schedule.total_hours)
      Logger.info("Time to send email #{is_send_time}")

      if is_send_time and is_nil(schedule.reminded_at) and !schedule.is_stopped do
        schema = if is_nil(gallery), do: job, else: gallery

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
    end)
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
end
