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
    Galleries,
    Repo,
    EmailAutomations,
    Accounts.User
  }

  import Ecto.Query

  setup do
    client_contact_pipeline =
      Repo.all(EmailAutomationPipeline)
      |> Enum.filter(fn email_preset -> email_preset.state == :client_contact end)
      |> List.first()

    organization = insert(:organization)

    user =
      insert(:user, organization: organization)
      |> User.assign_stripe_customer_changeset("general_customer")
      |> Repo.update!()

    plan = insert(:subscription_plan)
    insert(:subscription_event, user: user, subscription_plan: plan, status: "active")
    client = insert(:client, organization: organization)
    job = insert(:job, client_id: client.id)
    insert(:payment_schedule, job: job, paid_at: Timex.now())
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
    |> Mox.stub(:deliver_automation_email_job, fn _, _, _, _, _ ->
      {:ok, {:ok, "Email Sent"}}
    end)
    |> Mox.stub(:deliver_automation_email_gallery, fn _, _, _, _, _ ->
      {:ok, {:ok, "Email Sent"}}
    end)

    Picsello.PhotoStorageMock
    |> Mox.stub(:path_to_url, & &1)
    |> Mox.stub(:get, &{:ok, %{name: &1}})

    [
      email_1: email_1,
      email_2: email_2,
      email_3: email_3,
      job: job,
      organization: organization,
      user: user,
      plan: plan
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

  describe "send_now_email/4 action for shoots" do
    setup %{plan: plan} do
      shoot_organization = insert(:organization)

      shoot_user =
        insert(:user, organization: shoot_organization)
        |> User.assign_stripe_customer_changeset("shoot_customer")
        |> Repo.update!()

      insert(:subscription_event, user: shoot_user, subscription_plan: plan, status: "active")
      shoot_client = insert(:client, organization: shoot_organization)
      shoot_job = insert(:job, client_id: shoot_client.id)
      insert(:user_currency, user: shoot_user, organization: shoot_organization)

      insert_email_presets(
        "wedding",
        "job",
        shoot_organization,
        "active",
        1,
        "before_shoot",
        -24,
        1
      )

      insert_email_presets(
        "wedding",
        "job",
        shoot_organization,
        "active",
        1,
        "before_shoot",
        -168,
        7
      )

      insert_email_presets(
        "wedding",
        "job",
        shoot_organization,
        "active",
        1,
        "shoot_thanks",
        24,
        1
      )

      [shoot_organization: shoot_organization, shoot_job: shoot_job]
    end

    test "when the job is still in lead-status", %{
      shoot_job: shoot_job
    } do
      shoot = insert(:shoot, job: shoot_job, starts_at: Timex.shift(Timex.now(), days: 1))
      EmailAutomationSchedules.insert_shoot_emails(shoot_job, shoot)
      assert fetch_all_send_emails_count() == 0
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_shoot_emails_count() == 0
    end

    test "when the shoot date is tomorrow", %{
      shoot_job: shoot_job
    } do
      shoot = insert(:shoot, job: shoot_job, starts_at: Timex.shift(Timex.now(), days: 1))
      insert(:payment_schedule, job: shoot_job, paid_at: Timex.now())
      EmailAutomationSchedules.insert_shoot_emails(shoot_job, shoot)
      assert fetch_all_send_emails_count() == 0
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_shoot_emails_count() == 1
    end

    test "when the shoot date is day after tomorrow", %{
      shoot_job: shoot_job
    } do
      shoot = insert(:shoot, job: shoot_job, starts_at: Timex.shift(Timex.now(), days: 2))
      insert(:payment_schedule, job: shoot_job, paid_at: Timex.now())
      EmailAutomationSchedules.insert_shoot_emails(shoot_job, shoot)
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_shoot_emails_count() == 0
    end

    test "when the shoot date is 5 days after", %{
      shoot_job: shoot_job
    } do
      shoot = insert(:shoot, job: shoot_job, starts_at: Timex.shift(Timex.now(), days: 5))
      insert(:payment_schedule, job: shoot_job, paid_at: Timex.now())
      EmailAutomationSchedules.insert_shoot_emails(shoot_job, shoot)
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_shoot_emails_count() == 0
    end

    test "when the shoot date is 6 days after", %{
      shoot_job: shoot_job
    } do
      shoot = insert(:shoot, job: shoot_job, starts_at: Timex.shift(Timex.now(), days: 6))
      insert(:payment_schedule, job: shoot_job, paid_at: Timex.now())
      EmailAutomationSchedules.insert_shoot_emails(shoot_job, shoot)
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_shoot_emails_count() == 1
    end

    test "when the shoot date is 7 days after", %{
      shoot_job: shoot_job
    } do
      shoot = insert(:shoot, job: shoot_job, starts_at: Timex.shift(Timex.now(), days: 7))
      insert(:payment_schedule, job: shoot_job, paid_at: Timex.now())
      EmailAutomationSchedules.insert_shoot_emails(shoot_job, shoot)
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_shoot_emails_count() == 1
    end

    test "when the shoot date is 8 days after", %{
      shoot_job: shoot_job
    } do
      shoot = insert(:shoot, job: shoot_job, starts_at: Timex.shift(Timex.now(), days: 8))
      insert(:payment_schedule, job: shoot_job, paid_at: Timex.now())
      EmailAutomationSchedules.insert_shoot_emails(shoot_job, shoot)
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_shoot_emails_count() == 0
    end

    test "when the shoot date is 3 days before", %{
      shoot_job: shoot_job
    } do
      shoot = insert(:shoot, job: shoot_job, starts_at: Timex.shift(Timex.now(), days: -3))
      insert(:payment_schedule, job: shoot_job, paid_at: Timex.now())
      EmailAutomationSchedules.insert_shoot_emails(shoot_job, shoot)
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_shoot_emails_count() == 0
    end

    test "when the shoot date is 2 days before", %{
      shoot_job: shoot_job
    } do
      shoot = insert(:shoot, job: shoot_job, starts_at: Timex.shift(Timex.now(), days: -2))
      insert(:payment_schedule, job: shoot_job, paid_at: Timex.now())
      EmailAutomationSchedules.insert_shoot_emails(shoot_job, shoot)
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_shoot_emails_count() == 1
    end

    test "when the shoot date is 1 day before", %{
      shoot_job: shoot_job
    } do
      shoot = insert(:shoot, job: shoot_job, starts_at: Timex.shift(Timex.now(), days: -1))
      insert(:payment_schedule, job: shoot_job, paid_at: Timex.now())
      EmailAutomationSchedules.insert_shoot_emails(shoot_job, shoot)
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_shoot_emails_count() == 1
    end
  end

  describe "send_now_email/4 action for shoots with timezone Pacific/Niue" do
    setup %{plan: plan} do
      timezone_organization = insert(:organization)

      timezone_user =
        insert(:user, organization: timezone_organization, time_zone: "Pacific/Niue")
        |> User.assign_stripe_customer_changeset("niue_customer")
        |> Repo.update!()

      insert(:subscription_event, user: timezone_user, subscription_plan: plan, status: "active")

      timezone_client = insert(:client, organization: timezone_organization)
      timezone_job = insert(:job, client_id: timezone_client.id)
      insert(:user_currency, user: timezone_user, organization: timezone_organization)

      insert_email_presets(
        "wedding",
        "job",
        timezone_organization,
        "active",
        1,
        "before_shoot",
        -24,
        1
      )

      insert_email_presets(
        "wedding",
        "job",
        timezone_organization,
        "active",
        1,
        "before_shoot",
        -168,
        7
      )

      [timezone_organization: timezone_organization, timezone_job: timezone_job]
    end

    test "when the shoot date is tomorrow", %{
      timezone_job: timezone_job
    } do
      shoot = insert(:shoot, job: timezone_job, starts_at: Timex.shift(Timex.now(), days: 1))
      insert(:payment_schedule, job: timezone_job, paid_at: Timex.now())
      EmailAutomationSchedules.insert_shoot_emails(timezone_job, shoot)
      assert fetch_all_send_emails_count() == 0
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_shoot_emails_count() == 1
    end

    test "when the shoot date is 6 days after", %{
      timezone_job: timezone_job
    } do
      shoot = insert(:shoot, job: timezone_job, starts_at: Timex.shift(Timex.now(), days: 6))
      insert(:payment_schedule, job: timezone_job, paid_at: Timex.now())
      EmailAutomationSchedules.insert_shoot_emails(timezone_job, shoot)
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_shoot_emails_count() == 1
    end

    test "when the shoot date is 7 days after", %{
      timezone_job: timezone_job
    } do
      shoot = insert(:shoot, job: timezone_job, starts_at: Timex.shift(Timex.now(), days: 7))
      insert(:payment_schedule, job: timezone_job, paid_at: Timex.now())
      EmailAutomationSchedules.insert_shoot_emails(timezone_job, shoot)
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_shoot_emails_count() == 1
    end
  end

  describe "send_now_email/4 action for shoots with timezone Pacific/Kiritimati" do
    setup %{plan: plan} do
      timezone_organization = insert(:organization)

      timezone_user =
        insert(:user, organization: timezone_organization, time_zone: "Pacific/Kiritimati")
        |> User.assign_stripe_customer_changeset("kiritimati_customer")
        |> Repo.update!()

      insert(:subscription_event, user: timezone_user, subscription_plan: plan, status: "active")

      timezone_client = insert(:client, organization: timezone_organization)
      timezone_job = insert(:job, client_id: timezone_client.id)
      insert(:user_currency, user: timezone_user, organization: timezone_organization)

      insert_email_presets(
        "wedding",
        "job",
        timezone_organization,
        "active",
        1,
        "before_shoot",
        -24,
        1
      )

      insert_email_presets(
        "wedding",
        "job",
        timezone_organization,
        "active",
        1,
        "before_shoot",
        -168,
        7
      )

      [timezone_organization: timezone_organization, timezone_job: timezone_job]
    end

    test "when the shoot date is tomorrow", %{
      timezone_job: timezone_job
    } do
      shoot = insert(:shoot, job: timezone_job, starts_at: Timex.shift(Timex.now(), days: 1))
      insert(:payment_schedule, job: timezone_job, paid_at: Timex.now())
      EmailAutomationSchedules.insert_shoot_emails(timezone_job, shoot)
      assert fetch_all_send_emails_count() == 0
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_shoot_emails_count() == 1
    end

    test "when the shoot date is 6 days after", %{
      timezone_job: timezone_job
    } do
      shoot = insert(:shoot, job: timezone_job, starts_at: Timex.shift(Timex.now(), days: 6))
      insert(:payment_schedule, job: timezone_job, paid_at: Timex.now())
      EmailAutomationSchedules.insert_shoot_emails(timezone_job, shoot)
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_shoot_emails_count() == 1
    end

    test "when the shoot date is 7 days after", %{
      timezone_job: timezone_job
    } do
      shoot = insert(:shoot, job: timezone_job, starts_at: Timex.shift(Timex.now(), days: 7))
      insert(:payment_schedule, job: timezone_job, paid_at: Timex.now())
      EmailAutomationSchedules.insert_shoot_emails(timezone_job, shoot)
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_shoot_emails_count() == 1
    end
  end

  describe "send_now_email/4 action for follow-up emails" do
    setup %{plan: plan} do
      follow_up_organization = insert(:organization)

      follow_up_user =
        insert(:user, organization: follow_up_organization, time_zone: "Pacific/Kiritimati")
        |> User.assign_stripe_customer_changeset("follow_up_customer")
        |> Repo.update!()

      insert(:subscription_event, user: follow_up_user, subscription_plan: plan, status: "active")
      follow_up_client = insert(:client, organization: follow_up_organization)
      follow_up_job = insert(:job, client_id: follow_up_client.id)
      insert(:user_currency, user: follow_up_user, organization: follow_up_organization)

      insert_email_presets(
        "wedding",
        "lead",
        follow_up_organization,
        "active",
        1,
        "manual_thank_you_lead",
        0,
        1
      )

      insert_email_presets(
        "wedding",
        "lead",
        follow_up_organization,
        "active",
        1,
        "manual_thank_you_lead",
        72,
        3
      )

      insert_email_presets(
        "wedding",
        "lead",
        follow_up_organization,
        "active",
        1,
        "manual_thank_you_lead",
        96,
        4
      )

      insert_email_presets(
        "wedding",
        "lead",
        follow_up_organization,
        "active",
        1,
        "manual_thank_you_lead",
        120,
        5
      )

      [follow_up_organization: follow_up_organization, follow_up_job: follow_up_job]
    end

    test "when the difference is 2 days", %{
      follow_up_job: follow_up_job,
      follow_up_organization: follow_up_organization
    } do
      EmailAutomationSchedules.insert_job_emails(
        "wedding",
        follow_up_organization.id,
        follow_up_job.id,
        :lead
      )

      email = Repo.all(from(es in EmailSchedule, where: es.job_id == ^follow_up_job.id)) |> hd()

      EmailAutomations.send_now_email(
        :lead,
        email,
        follow_up_job,
        :manual_thank_you_lead
      )

      assert fetch_all_send_emails_count() == 1
      update_schedule_history(Timex.shift(Timex.now(), days: -2) |> DateTime.truncate(:second))
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_send_emails_count() == 1 + 3
    end

    test "when email is to be sent 3 days after", %{
      follow_up_job: follow_up_job,
      follow_up_organization: follow_up_organization
    } do
      EmailAutomationSchedules.insert_job_emails(
        "wedding",
        follow_up_organization.id,
        follow_up_job.id,
        :lead
      )

      email = Repo.all(from(es in EmailSchedule, where: es.job_id == ^follow_up_job.id)) |> hd()

      EmailAutomations.send_now_email(
        :lead,
        email,
        follow_up_job,
        :manual_thank_you_lead
      )

      assert fetch_all_send_emails_count() == 1
      update_schedule_history(Timex.shift(Timex.now(), days: -3) |> DateTime.truncate(:second))
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_send_emails_count() == 2 + 3
    end

    test "when email is to be sent 4 days after", %{
      follow_up_job: follow_up_job,
      follow_up_organization: follow_up_organization
    } do
      EmailAutomationSchedules.insert_job_emails(
        "wedding",
        follow_up_organization.id,
        follow_up_job.id,
        :lead
      )

      email = Repo.all(from(es in EmailSchedule, where: es.job_id == ^follow_up_job.id)) |> hd()

      EmailAutomations.send_now_email(
        :lead,
        email,
        follow_up_job,
        :manual_thank_you_lead
      )

      assert fetch_all_send_emails_count() == 1
      update_schedule_history(Timex.shift(Timex.now(), days: -4) |> DateTime.truncate(:second))
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_send_emails_count() == 2 + 3
    end

    test "when email is to be sent 5 days after", %{
      follow_up_job: follow_up_job,
      follow_up_organization: follow_up_organization
    } do
      EmailAutomationSchedules.insert_job_emails(
        "wedding",
        follow_up_organization.id,
        follow_up_job.id,
        :lead
      )

      email = Repo.all(from(es in EmailSchedule, where: es.job_id == ^follow_up_job.id)) |> hd()

      EmailAutomations.send_now_email(
        :lead,
        email,
        follow_up_job,
        :manual_thank_you_lead
      )

      assert fetch_all_send_emails_count() == 1
      update_schedule_history(Timex.shift(Timex.now(), days: -5) |> DateTime.truncate(:second))
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_send_emails_count() == 2 + 3
    end

    test "when the difference is 6 days", %{
      follow_up_job: follow_up_job,
      follow_up_organization: follow_up_organization
    } do
      EmailAutomationSchedules.insert_job_emails(
        "wedding",
        follow_up_organization.id,
        follow_up_job.id,
        :lead
      )

      email = Repo.all(from(es in EmailSchedule, where: es.job_id == ^follow_up_job.id)) |> hd()

      EmailAutomations.send_now_email(
        :lead,
        email,
        follow_up_job,
        :manual_thank_you_lead
      )

      assert fetch_all_send_emails_count() == 1
      update_schedule_history(Timex.shift(Timex.now(), days: -6) |> DateTime.truncate(:second))
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_send_emails_count() == 1 + 3
    end
  end

  describe "send_now_email/4 action for cart-abandoned emails" do
    setup %{plan: plan} do
      cart_organization = insert(:organization)

      cart_user =
        insert(:user, organization: cart_organization, time_zone: "Pacific/Kiritimati")
        |> User.assign_stripe_customer_changeset("cart_customer")
        |> Repo.update!()

      insert(:subscription_event, user: cart_user, subscription_plan: plan, status: "active")
      cart_client = insert(:client, organization: cart_organization)
      cart_job = insert(:job, client_id: cart_client.id, type: "wedding")
      insert(:user_currency, user: cart_user, organization: cart_organization)

      insert_email_presets(
        "wedding",
        "gallery",
        cart_organization,
        "active",
        1,
        "cart_abandoned",
        1,
        1
      )

      insert_email_presets(
        "wedding",
        "gallery",
        cart_organization,
        "active",
        1,
        "cart_abandoned",
        24,
        1
      )

      insert_email_presets(
        "wedding",
        "gallery",
        cart_organization,
        "active",
        1,
        "cart_abandoned",
        48,
        2
      )

      [cart_organization: cart_organization, cart_job: cart_job]
    end

    test "when the difference is less than 1 hour (doesn't sends the email)", %{
      cart_job: cart_job,
      cart_organization: cart_organization
    } do
      gallery =
        insert(:gallery,
          job: cart_job,
          organization: cart_organization
        )

      EmailAutomationSchedules.insert_gallery_order_emails(
        gallery,
        nil
      )

      gallery_client =
        insert(:gallery_client, gallery: gallery, email: "galleryclient@picsello.com")

      order =
        insert(:order,
          gallery: gallery,
          placed_at: nil,
          intent: nil,
          gallery_client: gallery_client,
          inserted_at: Timex.shift(Timex.now(), seconds: -360)
        )

      insert(:digital, order: order)

      assert fetch_all_send_emails_count() == 0
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_send_emails_count() == 3
    end

    test "when the difference is 1 hour (sends the email)", %{
      cart_job: cart_job,
      cart_organization: cart_organization
    } do
      gallery =
        insert(:gallery,
          job: cart_job,
          organization: cart_organization
        )

      EmailAutomationSchedules.insert_gallery_order_emails(
        gallery,
        nil
      )

      gallery_client =
        insert(:gallery_client, gallery: gallery, email: "galleryclient@picsello.com")

      order =
        insert(:order,
          gallery: gallery,
          placed_at: nil,
          intent: nil,
          gallery_client: gallery_client,
          inserted_at: Timex.shift(Timex.now(), hours: -1)
        )

      insert(:digital, order: order)

      assert fetch_all_send_emails_count() == 0
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_send_emails_count() == 4
    end

    test "when the difference is 3 hour (sends the email)", %{
      cart_job: cart_job,
      cart_organization: cart_organization
    } do
      gallery =
        insert(:gallery,
          job: cart_job,
          organization: cart_organization
        )

      EmailAutomationSchedules.insert_gallery_order_emails(
        gallery,
        nil
      )

      gallery_client =
        insert(:gallery_client, gallery: gallery, email: "galleryclient@picsello.com")

      order =
        insert(:order,
          gallery: gallery,
          placed_at: nil,
          intent: nil,
          gallery_client: gallery_client,
          inserted_at: Timex.shift(Timex.now(), hours: -3)
        )

      insert(:digital, order: order)

      assert fetch_all_send_emails_count() == 0
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_send_emails_count() == 4
    end

    test "when the difference is 4 hour (doesn't sends the email)", %{
      cart_job: cart_job,
      cart_organization: cart_organization
    } do
      gallery =
        insert(:gallery,
          job: cart_job,
          organization: cart_organization
        )

      EmailAutomationSchedules.insert_gallery_order_emails(
        gallery,
        nil
      )

      gallery_client =
        insert(:gallery_client, gallery: gallery, email: "galleryclient@picsello.com")

      order =
        insert(:order,
          gallery: gallery,
          placed_at: nil,
          intent: nil,
          gallery_client: gallery_client,
          inserted_at: Timex.shift(Timex.now(), hours: -4)
        )

      insert(:digital, order: order)

      assert fetch_all_send_emails_count() == 0
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_send_emails_count() == 3
    end

    test "when the difference is 1 day (sends the email)", %{
      cart_job: cart_job,
      cart_organization: cart_organization
    } do
      gallery =
        insert(:gallery,
          job: cart_job,
          organization: cart_organization
        )

      EmailAutomationSchedules.insert_gallery_order_emails(
        gallery,
        nil
      )

      gallery_client =
        insert(:gallery_client, gallery: gallery, email: "galleryclient@picsello.com")

      order =
        insert(:order,
          gallery: gallery,
          placed_at: nil,
          intent: nil,
          gallery_client: gallery_client,
          inserted_at: Timex.shift(Timex.now(), hours: -24)
        )

      insert(:digital, order: order)

      assert fetch_all_send_emails_count() == 0
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_send_emails_count() == 4
    end

    test "when the difference is 2 day (sends the email)", %{
      cart_job: cart_job,
      cart_organization: cart_organization
    } do
      gallery =
        insert(:gallery,
          job: cart_job,
          organization: cart_organization
        )

      EmailAutomationSchedules.insert_gallery_order_emails(
        gallery,
        nil
      )

      gallery_client =
        insert(:gallery_client, gallery: gallery, email: "galleryclient@picsello.com")

      order =
        insert(:order,
          gallery: gallery,
          placed_at: nil,
          intent: nil,
          gallery_client: gallery_client,
          inserted_at: Timex.shift(Timex.now(), hours: -48)
        )

      insert(:digital, order: order)

      assert fetch_all_send_emails_count() == 0
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_send_emails_count() == 4
    end

    test "when the difference is 3 day (doesn't sends the email)", %{
      cart_job: cart_job,
      cart_organization: cart_organization
    } do
      gallery =
        insert(:gallery,
          job: cart_job,
          organization: cart_organization
        )

      EmailAutomationSchedules.insert_gallery_order_emails(
        gallery,
        nil
      )

      gallery_client =
        insert(:gallery_client, gallery: gallery, email: "galleryclient@picsello.com")

      order =
        insert(:order,
          gallery: gallery,
          placed_at: nil,
          intent: nil,
          gallery_client: gallery_client,
          inserted_at: Timex.shift(Timex.now(), hours: -72)
        )

      insert(:digital, order: order)

      assert fetch_all_send_emails_count() == 0
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_send_emails_count() == 3
    end

    test "when the difference is 4 day (doesn't sends the email)", %{
      cart_job: cart_job,
      cart_organization: cart_organization
    } do
      gallery =
        insert(:gallery,
          job: cart_job,
          organization: cart_organization
        )

      EmailAutomationSchedules.insert_gallery_order_emails(
        gallery,
        nil
      )

      gallery_client =
        insert(:gallery_client, gallery: gallery, email: "galleryclient@picsello.com")

      order =
        insert(:order,
          gallery: gallery,
          placed_at: nil,
          intent: nil,
          gallery_client: gallery_client,
          inserted_at: Timex.shift(Timex.now(), hours: -96)
        )

      insert(:digital, order: order)

      assert fetch_all_send_emails_count() == 0
      Picsello.Workers.ScheduleAutomationEmail.perform(nil)
      assert fetch_all_send_emails_count() == 3
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
      insert_email_presets("wedding", "job", organization, "active", 4, "pays_retainer", 0, 1)
      EmailAutomationSchedules.insert_job_emails("wedding", organization.id, new_job.id, :job)
      assert EmailAutomationSchedules.get_active_email_schedule_count(new_job.id) == 4
    end

    test "return 10 when a job is created with any payments when there are 10 active emails", %{
      organization: organization,
      new_job: new_job
    } do
      insert(:payment_schedule, job: new_job)
      insert_email_presets("wedding", "job", organization, "active", 10, "pays_retainer", 0, 1)
      EmailAutomationSchedules.insert_job_emails("wedding", organization.id, new_job.id, :job)
      assert EmailAutomationSchedules.get_active_email_schedule_count(new_job.id) == 10
    end

    test "return 0 whenever a job is archived and garbage-collector has done its work", %{
      organization: organization,
      new_job: new_job
    } do
      insert(:payment_schedule, job: new_job)
      insert_email_presets("wedding", "job", organization, "active", 10, "pays_retainer", 0, 1)
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
      insert_email_presets("wedding", "job", organization, "active", 10, "pays_retainer", 0, 1)
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
      insert_email_presets("wedding", "job", organization, "active", 10, "pays_retainer", 0, 1)

      insert_email_presets(
        "wedding",
        "gallery",
        organization,
        "active",
        2,
        "gallery_expiration_soon",
        0,
        1
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
      insert_email_presets("wedding", "job", organization, "active", 10, "pays_retainer", 0, 1)

      insert_email_presets(
        "wedding",
        "gallery",
        organization,
        "active",
        2,
        "gallery_expiration_soon",
        0,
        1
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

    EmailAutomationSchedules.delete_and_insert_schedules_by_multi(
      schedule_query,
      :photographer_stopped
    )
    |> Repo.transaction()
  end

  defp fetch_all_send_emails_count() do
    from(esh in EmailScheduleHistory, where: not is_nil(esh.reminded_at))
    |> Repo.all()
    |> Enum.count()
  end

  defp fetch_all_shoot_emails_count() do
    from(esh in EmailScheduleHistory, where: not is_nil(esh.reminded_at) and esh.type == :shoot)
    |> Repo.all()
    |> Enum.count()
  end

  defp insert_email_presets(
         job_type,
         type,
         organization,
         status,
         iterator,
         state,
         total_hours,
         count
       ) do
    pipelines = from(p in EmailAutomationPipeline) |> Repo.all()
    %{sign: sign} = EmailAutomations.explode_hours(total_hours)

    Enum.map(1..iterator, fn _x ->
      %{
        email_automation_pipeline_id: get_pipeline_id_by_state(pipelines, state),
        total_hours: total_hours,
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
        immediately: if(total_hours == 0, do: true, else: false),
        count: count,
        calendar: if(total_hours == 1, do: "Hour", else: "Day"),
        sign: sign,
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

    EmailAutomationSchedules.delete_and_insert_schedules_by_multi(
      email_schedules_query,
      :archived
    )
    |> Repo.transaction()
  end

  defp update_schedule_history(reminded_at) do
    history = from(esh in EmailScheduleHistory) |> Repo.all() |> hd()
    history = Ecto.Changeset.change(history, reminded_at: reminded_at)
    Repo.update(history)
  end
end
