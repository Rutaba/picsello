defmodule Mix.Tasks.ImportEmailForAlreadyCreatedJobs do
  @moduledoc false

  use Mix.Task
  require Logger
  import Ecto.Query
  alias PicselloWeb.EmailAutomationLive.Shared

  alias Picsello.{
    Repo,
    Job,
    Galleries,
    Accounts.User
  }

  @shortdoc "import email schedules for ongoing jobs"
  def run(_) do
    load_app()

    organizations =
      from(u in User,
        select: %{id: u.organization_id},
        where:
          u.email in [
            "apple@gmail.com",
            "rhinop+picsello@gmail.com",
            "ops+demo@picsello.com",
            "aatanasio.dempsey@gmail.com",
            "kyle+22@picsello.com",
            "xanadupod@workwithloop.com",
            "kyle+marketing@picsello.com",
            "kyle+jane@picsello.com",
            "gallerytest@gallerytest.com"
          ]
      )
      |> Repo.all()

    organizations
    |> Enum.map(fn org ->
      user = %User{organization_id: org.id}

      user
      |> Job.for_user()
      |> Job.leads()
      |> Job.not_booking()
      |> filter_jobs()
      |> leads_emails_insert(org.id)

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
      skip_states =
        if is_skip_states?(job.payment_schedules),
          do: [""],
          else: [:balance_due, :offline_payment, :paid_full, :paid_offline_full]

      insert_email_schedules_job(job.type, job.id, org_id, [:job], skip_states)
      galleries_emails(job.galleries)
    end)
  end

  defp is_skip_states?(payment_schedules),
    do:
      payment_schedules
      |> Enum.any?(&is_nil(&1.reminded_at))

  defp galleries_emails(galleries) do
    galleries
    |> Enum.filter(&(&1.status == :active and !Galleries.expired?(&1)))
    |> Enum.map(fn gallery ->
      Shared.insert_gallery_order_emails(gallery, nil)
      order_emails(gallery.orders)
    end)
  end

  defp order_emails(orders) do
    Enum.map(orders, fn order ->
      Shared.insert_gallery_order_emails(nil, order)
    end)
  end

  defp insert_email_schedules_job(
         job_type,
         job_id,
         organization_id,
         categories,
         skip_pipelines
       ) do
    Shared.insert_job_emails(job_type, organization_id, job_id, categories, skip_pipelines)
  end

  defp filter_jobs(query) do
    from(j in query, preload: [:job_status, :payment_schedules, galleries: :orders])
    |> Repo.all()
    |> Enum.filter(&(is_nil(&1.archived_at) and is_nil(&1.completed_at)))
  end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
