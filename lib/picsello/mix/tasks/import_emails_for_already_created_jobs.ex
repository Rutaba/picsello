defmodule Mix.Tasks.ImportEmailForAlreadyCreatedJobs do
  @moduledoc false

  use Mix.Task
  require Logger
  import Ecto.Query

  alias Picsello.{
    Repo,
    Job,
    Galleries,
    Accounts.User,
    EmailAutomationSchedules
  }

  @shortdoc "import email schedules for ongoing jobs"
  def run(_) do
    load_app()

    from(o in Picsello.Organization, select: %{id: o.id})
    |> Repo.all()
    |> Enum.map(fn org ->
      user = %User{organization_id: org.id}

      # Leads emails insert
      user
      |> Job.for_user()
      |> Job.leads()
      |> Job.not_booking()
      |> filter_jobs()
      |> leads_emails_insert(org.id)

      # Job Gallery Order emails insert
      user
      |> Job.for_user()
      |> Job.not_leads()
      |> filter_jobs()
      |> jobs_emails_insert(org.id)

      user
    end)
  end

  defp leads_emails_insert(leads, org_id) do
    Enum.map(leads, fn lead ->
      insert_email_schedules_job(lead.type, lead.id, org_id, [:lead], [
        :client_contact,
        :abandoned_emails
      ])
    end)
  end

  defp jobs_emails_insert(jobs, org_id) do
    Enum.map(jobs, fn job ->
      skip_states = skip_job_states(job)
      insert_email_schedules_job(job.type, job.id, org_id, [:job], skip_states)
      galleries_emails(job.galleries)
    end)
  end

  defp skip_job_states(job) do
    skip_booking_states =
      if Enum.any?(job.payment_schedules),
        do: [:pays_retainer, :thanks_booking, :pays_retainer_offline],
        else: []

    skip_payment_states =
      if is_payment_states_keep?(job.payment_schedules) or Enum.empty?(job.payment_schedules),
        do: [],
        else: [:balance_due, :offline_payment, :paid_full, :paid_offline_full]

    skip_shoot_states = skipping_actions_for_shoots(job.shoots)

    skip_booking_states ++ skip_payment_states ++ skip_shoot_states
  end

  defp skipping_actions_for_shoots(shoots) do
    case {has_shoots_before_now?(shoots), has_shoots_before_48_hours?(shoots)} do
      {true, true} -> [:before_shoot, :shoot_thanks]
      {true, _} -> [:before_shoot]
      _ -> []
    end
  end

  defp has_shoots_before_now?(shoots),
    do: Enum.any?(shoots, &(Date.diff(&1.starts_at, Timex.now()) < 0))

  defp has_shoots_before_48_hours?(shoots),
    do: Enum.any?(shoots, &(Date.diff(&1.starts_at |> Timex.shift(days: 2), Timex.now()) < 0))

  defp is_payment_states_keep?(payment_schedules),
    do:
      payment_schedules
      |> Enum.any?(&is_nil(&1.reminded_at))

  defp galleries_emails(galleries) do
    galleries
    |> Enum.filter(&(&1.status == :active and !Galleries.expired?(&1)))
    |> Enum.map(fn gallery ->
      if Enum.count(gallery.orders) > 0,
        do: order_emails(gallery.orders),
        else: EmailAutomationSchedules.insert_gallery_order_emails(gallery, nil)
    end)
  end

  defp order_emails(orders) do
    Enum.map(orders, fn order ->
      EmailAutomationSchedules.insert_gallery_order_emails(nil, order)
    end)
  end

  defp insert_email_schedules_job(
         job_type,
         job_id,
         organization_id,
         categories,
         skip_pipelines
       ) do
    EmailAutomationSchedules.insert_job_emails(
      job_type,
      organization_id,
      job_id,
      categories,
      skip_pipelines
    )
  end

  defp filter_jobs(query) do
    from(j in query, preload: [:job_status, :shoots, :payment_schedules, galleries: :orders])
    |> Repo.all()
    |> Enum.filter(&(is_nil(&1.archived_at) and is_nil(&1.completed_at)))
  end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
