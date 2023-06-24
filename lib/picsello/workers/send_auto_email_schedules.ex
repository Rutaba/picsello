defmodule Picsello.Workers.ScheduleEmail1 do
  @moduledoc "Background job to send scheduled emails"
  use Oban.Worker,
    unique: [period: :infinity, states: ~w[available scheduled executing retryable]a]

  alias Picsello.EmailAutomation

  def perform(_) do
    EmailAutomation.get_all_emails_schedules()
    |> Enum.group_by(&group_key/1)
    |> Enum.map(fn {{job_id, gallery_id, pipeline_id}, emails} ->
      %{
        job_id: job_id,
        gallery_id: gallery_id,
        pipeline_id: pipeline_id,
        emails: emails
      }
    end)
    |> Enum.map(fn job_pipeline ->
      job_id = job_pipeline.job_id
      job_task = Task.async(fn -> EmailAutomation.get_job(job_id) end)
      type = job_pipeline.emails |> List.first() |> Map.get(:email_automation_pipeline) |> Map.get(:email_automation_category) |> Map.get(:type)
      _gallery_id = job_pipeline.gallery_id
      subjects_task = Task.async(fn -> EmailAutomation.get_subjects_for_job_pipeline(job_pipeline.emails) end)
      job = Task.await(job_task)
      subjects = Task.await(subjects_task)
      # Each pipeline emails subjects resolve variables
      subjects_resolve = EmailAutomation.resolve_all_subjects(job, type, subjects)
      # Check client reply for any email of current pipeline
      is_reply = EmailAutomation.is_reply_receive!(job, subjects_resolve)
      # This condition only run when no reply recieve from any email for that job & pipeline
      if !is_reply do
        Enum.map(job_pipeline.emails, fn schedule ->
          state = schedule.email_automation_pipeline.state
          type = schedule.email_automation_pipeline.email_automation_category.type
          job_date_time = EmailAutomation.fetch_date_for_state(state, job)
          is_send_time = EmailAutomation.is_email_send_time(job_date_time, schedule.total_hours)
          if is_send_time and is_nil(schedule.reminded_at) do
            Task.async(fn -> EmailAutomation.send_now_email(type, schedule, job, state) end)
          end
        end)
      end
    end)
    :ok
  end

  defp group_key(email_schedule) do
    if email_schedule.job_id != nil do
      {email_schedule.job_id, nil, email_schedule.email_automation_pipeline_id}
    else
      {nil, email_schedule.gallery_id, email_schedule.email_automation_pipeline_id}
    end
  end
end
