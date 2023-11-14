defmodule Picsello.EmailAutomationsTest do
  use Picsello.DataCase, async: true

  alias Picsello.{
    EmailAutomationNotifierMock,
    EmailAutomation.EmailSchedule,
    EmailAutomation.EmailScheduleHistory,
    EmailAutomation.EmailAutomationPipeline,
    EmailAutomationSchedules,
    EmailPresets.EmailPreset,
    Jobs,
    Galleries
  }

  import Ecto.Query

  setup do
    client_contact_pipeline =
      Repo.all(EmailAutomationPipeline)
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

    [
      email_1: email_1,
      email_2: email_2,
      email_3: email_3,
      job: job,
      organization: organization,
      user: user
    ]
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

  describe "get_active_email_schedule_count/1 action" do
    setup %{organization: organization} do
      client = insert(:client, organization: organization)
      package = insert(:package)
      new_job = insert(:job, client: client, package: package)

      [new_job: new_job]
    end

    test "return active email count", %{job: job} do
      assert EmailAutomationSchedules.get_active_email_schedule_count(job.id) == 3
    end

    test "return 0 when a job is created without any payments", %{
      organization: organization,
      new_job: new_job
    } do
      EmailAutomationSchedules.insert_job_emails("wedding", organization.id, new_job.id, :job)
      assert EmailAutomationSchedules.get_active_email_schedule_count(new_job.id) == 0
    end

    test "return 4 when a job is created with any payments when there are 4 active emails", %{
      organization: organization,
      new_job: new_job
    } do
      insert(:payment_schedule, job: new_job)
      insert_email_presets("wedding", "job", organization, "active", 4, "pays_retainer")
      EmailAutomationSchedules.insert_job_emails("wedding", organization.id, new_job.id, :job)
      assert EmailAutomationSchedules.get_active_email_schedule_count(new_job.id) == 4
    end

    test "return 10 when a job is created with any payments when there are 10 active emails", %{
      organization: organization,
      new_job: new_job
    } do
      insert(:payment_schedule, job: new_job)
      insert_email_presets("wedding", "job", organization, "active", 10, "pays_retainer")
      EmailAutomationSchedules.insert_job_emails("wedding", organization.id, new_job.id, :job)
      assert EmailAutomationSchedules.get_active_email_schedule_count(new_job.id) == 10
    end

    test "return 0 whenever a job is archived and garbage-collector has done its work", %{
      organization: organization,
      new_job: new_job
    } do
      insert(:payment_schedule, job: new_job)
      insert_email_presets("wedding", "job", organization, "active", 10, "pays_retainer")
      EmailAutomationSchedules.insert_job_emails("wedding", organization.id, new_job.id, :job)
      Jobs.archive_job(new_job)
      stop_archived_emails(new_job)
      assert EmailAutomationSchedules.get_active_email_schedule_count(new_job.id) == 0
    end

    test "return number of active-emails whenever a job is unarchived", %{
      organization: organization,
      new_job: new_job
    } do
      insert(:payment_schedule, job: new_job)
      insert_email_presets("wedding", "job", organization, "active", 10, "pays_retainer")
      EmailAutomationSchedules.insert_job_emails("wedding", organization.id, new_job.id, :job)
      Jobs.unarchive_job(new_job)
      assert EmailAutomationSchedules.get_active_email_schedule_count(new_job.id) == 10
    end

    test "return only gallery-emails count when a gallery is created in a fully-paid job", %{
      organization: organization,
      user: user,
      new_job: new_job
    } do
      insert(:payment_schedule, job: new_job, paid_at: Timex.now())
      insert_email_presets("wedding", "job", organization, "active", 10, "pays_retainer")

      insert_email_presets(
        "wedding",
        "gallery",
        organization,
        "active",
        2,
        "gallery_expiration_soon"
      )

      EmailAutomationSchedules.insert_job_emails("wedding", organization.id, new_job.id, :job)
      assert EmailAutomationSchedules.get_active_email_schedule_count(new_job.id) == 0

      Galleries.create_gallery(user, %{
        name: "Test Gallery",
        job_id: new_job.id,
        organization_id: organization.id,
        status: :active
      })

      assert EmailAutomationSchedules.get_active_email_schedule_count(new_job.id) == 2

      Galleries.create_gallery(user, %{
        name: "Test Gallery 2",
        job_id: new_job.id,
        organization_id: organization.id,
        status: :active
      })

      assert EmailAutomationSchedules.get_active_email_schedule_count(new_job.id) == 4

      Galleries.create_gallery(user, %{
        name: "Test Gallery 3",
        job_id: new_job.id,
        organization_id: organization.id,
        status: :active
      })

      assert EmailAutomationSchedules.get_active_email_schedule_count(new_job.id) == 6
    end

    test "return all the emails count related to gallery and job when a gallery is created in a partially-paid job",
         %{
           organization: organization,
           user: user,
           new_job: new_job
         } do
      insert(:payment_schedule, job: new_job)
      insert_email_presets("wedding", "job", organization, "active", 10, "pays_retainer")

      insert_email_presets(
        "wedding",
        "gallery",
        organization,
        "active",
        2,
        "gallery_expiration_soon"
      )

      EmailAutomationSchedules.insert_job_emails("wedding", organization.id, new_job.id, :job)

      Galleries.create_gallery(user, %{
        name: "Test Gallery",
        job_id: new_job.id,
        organization_id: organization.id,
        status: :active
      })

      assert EmailAutomationSchedules.get_active_email_schedule_count(new_job.id) == 12
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

  defp insert_email_presets(job_type, type, organization, status, iterator, state) do
    pipelines = from(p in EmailAutomationPipeline) |> Repo.all()

    Enum.map(1..iterator, fn _x ->
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, state),
        total_hours: 0,
        status: status,
        job_type: job_type,
        type: type,
        position: 0,
        name: "TEST EMAIL PRESET NAME",
        subject_template: "TEST EMAIL PRESET SUBJECT",
        body_template: """
        <p>TEST EMAIL PRESET TEMPLATE</p>
        """
      }
    end)
    |> Enum.each(fn attrs ->
      state = get_state_by_pipeline_id(pipelines, attrs.email_automation_pipeline_id)

      Map.merge(attrs, %{
        organization_id: organization.id,
        state: Atom.to_string(state),
        inserted_at: Timex.now(),
        updated_at: Timex.now()
      })
      |> EmailPreset.changeset()
      |> Repo.insert!()
    end)
  end

  defp get_pipeline_id_by_state(pipelines, state) do
    pipeline =
      pipelines
      |> Enum.filter(&(&1.state == String.to_atom(state)))
      |> List.first()

    pipeline.id
  end

  defp get_state_by_pipeline_id(pipelines, id) do
    pipeline =
      pipelines
      |> Enum.filter(&(&1.id == id))
      |> List.first()

    pipeline.state
  end

  defp stop_archived_emails(job) do
    email_schedules_query = from(es in EmailSchedule, where: es.job_id == ^job.id)

    EmailAutomationSchedules.delete_and_insert_schedules_by(
      email_schedules_query,
      :archived
    )
  end
end
