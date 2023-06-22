defmodule Picsello.Workers.ScheduleEmail1 do
  @moduledoc "Background job to send scheduled emails"
  use Oban.Worker,
    unique: [period: :infinity, states: ~w[available scheduled executing retryable]a]

  alias Picsello.EmailAutomation

  def perform(_) do
    email_schedules = EmailAutomation.get_emails_schedules()

    Enum.map(email_schedules, fn schedule ->
      state = schedule.email_automation_pipeline.state
      type = schedule.email_automation_pipeline.email_automation_category.type

      job_task = Task.async(fn -> EmailAutomation.get_job(schedule.job_id) end)
      job = Task.await(job_task)

      job_date_time_task = Task.async(fn -> EmailAutomation.fetch_date_for_state(state, job) end)
      job_date_time = Task.await(job_date_time_task)

      if EmailAutomation.is_email_send_time(job_date_time, schedule.total_hours) and
           is_nil(schedule.reminded_at) do
        Task.async(fn ->
          EmailAutomation.send_now_email(type, schedule, job, state)
        end)
      else
        nil
      end
    end)

    :ok
  end
end
