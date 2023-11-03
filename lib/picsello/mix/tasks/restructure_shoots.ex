defmodule Mix.Tasks.RestructureShoots do
  @moduledoc """
  This module defines a Mix task for restructuring shoots in the Picsello application.
  It is used to update and reflect changes in shoots, job scheduling, and email automation pipelines.

  To use this task, run `mix restructure_shoots`.
  """

  use Mix.Task

  import Ecto.Query
  alias Ecto.{Changeset, Multi}

  alias Picsello.{
    Repo,
    EmailAutomation.EmailAutomationSubCategory,
    EmailAutomation.EmailAutomationPipeline,
    EmailAutomation.EmailSchedule,
    EmailAutomation.EmailScheduleHistory,
    Organization,
    Accounts.User,
    Job,
    EmailAutomations,
    EmailAutomationSchedules
  }

  @shortdoc "Run the restructuring process for shoots, jobs, and email automation."
  def run(_) do
    load_app()

    insert_new_sub_category()
    reflect_restructure_shoots_changes_in_leads_and_jobs()
  end

  def reflect_restructure_shoots_changes_in_leads_and_jobs() do
    before_shoot_pipeline = EmailAutomations.get_pipeline_by_state("before_shoot")
    shoot_thanks_pipeline = EmailAutomations.get_pipeline_by_state("shoot_thanks")

    from(o in Organization, select: %{id: o.id})
    |> Repo.all()
    |> Enum.each(fn org ->
      user = %User{organization_id: org.id}

      jobs_with_shoots =
        user
        |> Job.for_user()
        |> with_shoots()
        |> not_archived()

      Enum.each(jobs_with_shoots, fn job ->
        before_shoot_schedules =
          from(es in EmailSchedule,
            where:
              es.email_automation_pipeline_id == ^before_shoot_pipeline.id and
                es.job_id == ^job.id and
                es.organization_id == ^org.id
          )

        shoot_thanks_schedules =
          from(es in EmailSchedule,
            where:
              es.email_automation_pipeline_id == ^shoot_thanks_pipeline.id and
                es.job_id == ^job.id and
                es.organization_id == ^org.id
          )

        shoot_history_schedules =
          from(es in EmailScheduleHistory,
            where:
              es.email_automation_pipeline_id in ^[
                before_shoot_pipeline.id,
                shoot_thanks_pipeline.id
              ] and
                es.job_id == ^job.id and
                es.organization_id == ^org.id
          )

        first_shoot =
          if Enum.any?(job.shoots) do
            [first_shoot | _rest] = job.shoots |> Enum.sort_by(& &1.starts_at, :asc)
            first_shoot
          end

        {:ok, _} =
          shoots_multi_transactions(
            before_shoot_schedules,
            shoot_thanks_schedules,
            first_shoot,
            shoot_history_schedules
          )

        email_schedules = from(es in EmailSchedule, where: es.job_id == ^job.id) |> Repo.all()

        if Enum.any?(email_schedules) do
          job.shoots |> Enum.map(&EmailAutomationSchedules.insert_shoot_emails(job, &1))
        end
      end)
    end)
  end

  defp with_shoots(job) do
    job
    |> preload([:shoots])
    |> Repo.all()
  end

  defp not_archived(job) do
    job
    |> Enum.filter(&is_nil(&1.archived_at))
  end

  defp shoots_multi_transactions(
         before_shoot_schedules,
         shoot_thanks_schedules,
         first_shoot,
         shoot_history_schedules
       ) do
    Multi.new()
    |> Multi.delete_all(:before_shoot_schedules, before_shoot_schedules)
    |> Multi.delete_all(:shoot_thanks_schedules, shoot_thanks_schedules)
    |> then(fn multi ->
      if first_shoot do
        multi
        |> Multi.update_all(:shoot_history_schedules, shoot_history_schedules,
          set: [type: :shoot, shoot_id: first_shoot.id]
        )
      else
        multi
        |> Multi.delete_all(:shoot_history_schedules, shoot_history_schedules)
      end
    end)
    |> Repo.transaction()
  end

  def insert_new_sub_category() do
    sub_categories = from(sc in EmailAutomationSubCategory) |> Repo.all()

    {:ok, automation_post_job} =
      maybe_insert_email_automation_slug(
        sub_categories,
        "Post Job emails",
        "post_job_emails",
        7.5
      )

    Repo.get_by(EmailAutomationPipeline, state: "post_shoot")
    |> Changeset.change(email_automation_sub_category_id: automation_post_job.id)
    |> Repo.update()
  end

  defp maybe_insert_email_automation_slug(sub_categories, name, slug, position) do
    sub_category = Enum.filter(sub_categories, &(&1.slug == slug)) |> List.first()

    if sub_category do
      sub_category
      |> EmailAutomationSubCategory.changeset(%{name: name})
      |> Repo.update()
    else
      %EmailAutomationSubCategory{}
      |> EmailAutomationSubCategory.changeset(%{
        name: name,
        slug: slug,
        position: position
      })
      |> Repo.insert()
    end
  end

  defp load_app do
    if System.get_env("MIX_ENV") != "prod" do
      Mix.Task.run("app.start")
    end
  end
end
