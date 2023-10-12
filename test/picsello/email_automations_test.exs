defmodule Picsello.EmailAutomationsTest do
  use Picsello.DataCase, async: true
  alias Picsello.EmailAutomationNotifierMock

  setup do
    client_contact_pipeline =
      Repo.all(Picsello.EmailAutomation.EmailAutomationPipeline)
      |> Enum.filter(fn email_preset -> email_preset.state == :client_contact end)
      |> List.first()

    organization = insert(:organization)
    insert(:user, organization: organization)
    client = insert(:client, organization: organization)
    job = insert(:job, client_id: client.id)

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
    |> Mox.expect(:deliver_automation_email_job, 1, fn _, _, _, _, _ ->
      {:ok, {:ok, "Email Sent"}}
    end)

    [email_1: email_1, email_2: email_2, email_3: email_3]
  end

  describe "send_now_email/4 action" do
    test "sends the immediately scheduled-emails" do
      assert Repo.all(Picsello.EmailAutomation.EmailScheduleHistory) |> Enum.count() == 0
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert Repo.all(Picsello.EmailAutomation.EmailScheduleHistory) |> Enum.count() == 3
    end

    test "sends the adjacent immediately scheduled-emails even if 2nd email is stopped", %{
      email_2: email
    } do
      assert Repo.all(Picsello.EmailAutomation.EmailScheduleHistory) |> Enum.count() == 0

      Picsello.EmailAutomationSchedules.update_email_schedule(email.id, %{stopped_at: Timex.now()})

      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert Repo.all(Picsello.EmailAutomation.EmailScheduleHistory) |> Enum.count() == 2
    end

    test "sends the upcoming immediately scheduled-emails even if 1st email is stopped", %{
      email_1: email
    } do
      assert Repo.all(Picsello.EmailAutomation.EmailScheduleHistory) |> Enum.count() == 0

      Picsello.EmailAutomationSchedules.update_email_schedule(email.id, %{stopped_at: Timex.now()})

      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert Repo.all(Picsello.EmailAutomation.EmailScheduleHistory) |> Enum.count() == 2
    end

    test "sends the first 2 scheduled emails if the 3rd one is stopped", %{email_3: email} do
      assert Repo.all(Picsello.EmailAutomation.EmailScheduleHistory) |> Enum.count() == 0

      Picsello.EmailAutomationSchedules.update_email_schedule(email.id, %{stopped_at: Timex.now()})

      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert Repo.all(Picsello.EmailAutomation.EmailScheduleHistory) |> Enum.count() == 2
    end
  end
end
