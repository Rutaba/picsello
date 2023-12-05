defmodule Picsello.Repo.Migrations.AddThanksJobEmailsInPresets do
  use Ecto.Migration

  import Ecto.Query

  alias Picsello.{
    Repo,
    EmailAutomations,
    Organization,
    EmailAutomation.EmailAutomationPipeline
  }

  alias Mix.Tasks.ImportEmailPresets, as: Presets

  def change do
    _pipeline = insert_state()
    pipelines = from(p in EmailAutomationPipeline) |> Repo.all()

    organizations = from(o in Organization, select: %{id: o.id}) |> Repo.all()

    pipeline = EmailAutomations.get_pipeline_by_state(:thanks_job)

    thanks_job_email = %{
      email_automation_pipeline_id: pipeline.id,
      total_hours: 0,
      status: "active",
      job_type: "wedding",
      type: "job",
      position: 0,
      name: "Thank you for booking email",
      subject_template: "Thank you for booking with {{photography_company_s_name}}",
      body_template: """
      <p><span style="color: rgb(0, 0, 0);">Hello {{client_first_name}}, </span></p>
      <p><span style="color: rgb(0, 0, 0);">You are officially booked for your photoshoot. I'm looking forward to working with you.</span></p>
      <p><span style="color: rgb(0, 0, 0);">After your photoshoot, your images will be delivered via a beautiful online gallery within {{delivery_time}} of your session date.</span></p>
      <p><span style="color: rgb(0, 0, 0);">Any questions, please feel free to let me know! </span></p>
      <p><span style="color: rgb(0, 0, 0);">{{email_signature}}</span></p>
      """
    }

    job_types = [
      "wedding",
      "newborn",
      "family",
      "mini",
      "headshot",
      "portrait",
      "boudoir",
      "global",
      "maternity",
      "event"
    ]

    Enum.map(job_types, fn type ->
      Map.put(thanks_job_email, :job_type, type)
    end)
    |> Presets.insert_presets(pipelines, organizations)
  end

  defp insert_state() do
    pipeline = EmailAutomations.get_pipeline_by_state(:thanks_booking)

    pipeline_thanks_job = EmailAutomations.get_pipeline_by_state(:thanks_job)

    if is_nil(pipeline_thanks_job) do
      %{
        name: "Thank You for Booking Job",
        state: "thanks_job",
        description: "Sent when the questionnaire, contract is signed and retainer is paid",
        email_automation_sub_category_id: pipeline.email_automation_sub_category_id,
        email_automation_category_id: pipeline.email_automation_category_id,
        position: 7.5,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }
      |> EmailAutomationPipeline.changeset()
      |> Repo.insert!()
    end
  end
end
