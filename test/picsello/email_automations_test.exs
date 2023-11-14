defmodule Picsello.EmailAutomationsTest do
  use Picsello.DataCase, async: true

  alias Picsello.{
    EmailAutomationNotifierMock,
    EmailAutomation.EmailScheduleHistory,
    EmailAutomationSchedules
  }

  import Ecto.Query

  setup do
    client_contact_pipeline =
      Repo.all(Picsello.EmailAutomation.EmailAutomationPipeline)
      |> Enum.filter(fn email_preset -> email_preset.state == :client_contact end)
      |> List.first()

    organization = insert(:organization)
    user = insert(:user, organization: organization)
    client = insert(:client, organization: organization)
    job = insert(:job, client_id: client.id)
    insert(:payment_schedule, job: job)
    insert(:user_currency, user: user, organization: organization)

    email_1 =
      insert(:email_schedule,
        name: "Email 1",
        email_automation_pipeline_id: client_contact_pipeline.id,
        organization_id: organization.id,
        job_id: job.id
      )

    email_2 =
      insert(:email_schedule,
        name: "Email 2",
        email_automation_pipeline_id: client_contact_pipeline.id,
        organization_id: organization.id,
        job_id: job.id
      )

    email_3 =
      insert(:email_schedule,
        name: "Email 3",
        email_automation_pipeline_id: client_contact_pipeline.id,
        organization_id: organization.id,
        job_id: job.id
      )

    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)

    EmailAutomationNotifierMock
    |> Mox.expect(:deliver_automation_email_job, 3, fn _, _, _, _, _ ->
      {:ok, {:ok, "Email Sent"}}
    end)

    [email_1: email_1, email_2: email_2, email_3: email_3]
  end

  describe "send_now_email/4 action" do
    test "sends the immediately scheduled-emails" do
      assert fetch_all_send_emails_count() == 0
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_send_emails_count() == 3
    end

    test "sends the adjacent immediately scheduled-emails even if 2nd email is stopped", %{
      email_2: email
    } do
      assert fetch_all_send_emails_count() == 0
      stop_email(email)

      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_send_emails_count() == 2
    end

    test "sends the upcoming immediately scheduled-emails even if 1st email is stopped", %{
      email_1: email
    } do
      assert fetch_all_send_emails_count() == 0

      stop_email(email)

      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_send_emails_count() == 2
    end

    test "sends the first 2 scheduled emails if the 3rd one is stopped", %{email_3: email} do
      assert fetch_all_send_emails_count() == 0

      stop_email(email)

      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_send_emails_count() == 2
    end
  end

  defp stop_email(email) do
    schedule_query = EmailAutomationSchedules.get_schedule_by_id_query(email.id)
    EmailAutomationSchedules.delete_and_insert_schedules_by(schedule_query, :photographer_stopped)
  end

  defp fetch_all_send_emails_count() do
    from(esh in EmailScheduleHistory, where: not is_nil(esh.reminded_at))
    |> Repo.all()
    |> Enum.count()
  end
end
