defmodule Picsello.EmailAutomationSchedules do
  @moduledoc """
    context module for email automation
  """
  import Ecto.Query

  alias Picsello.{
    Repo,
    EmailAutomation.EmailSchedule
  }

  def get_schedule_by_id(id) do
    from(es in EmailSchedule, where: es.id == ^id)
    |> Repo.one()
  end

  def get_active_email_schedule_count(job_id) do
    from(es in EmailSchedule,
      where: not es.is_stopped and is_nil(es.reminded_at) and es.job_id == ^job_id
    )
    |> Repo.aggregate(:count)
  end

  def get_email_schedules_by_ids(ids, type) do
    query =
      from(
        es in EmailSchedule,
        join: p in assoc(es, :email_automation_pipeline),
        join: c in assoc(p, :email_automation_category),
        select: %{
          category_type: c.type,
          category_id: c.id,
          job_id: es.job_id,
          pipeline:
            fragment(
              "to_jsonb(json_build_object('id', ?, 'name', ?, 'state', ?, 'description', ?, 'email', ?))",
              p.id,
              p.name,
              p.state,
              p.description,
              fragment(
                "to_jsonb(json_build_object('id', ?, 'name', ?, 'total_hours', ?, 'condition', ?, 'body_template', ?, 'subject_template', ?, 'private_name', ?, 'is_stopped', ?, 'reminded_at', ?))",
                es.id,
                es.name,
                es.total_hours,
                es.condition,
                es.body_template,
                es.private_name,
                es.private_name,
                es.is_stopped,
                es.reminded_at
              )
            )
        }
      )

    query
    |> filter_email_schedule(ids, type)
    |> Repo.all()
    |> email_schedules_group_by_categories()
  end

  def get_all_emails_schedules() do
    from(es in EmailSchedule)
    |> preload(email_automation_pipeline: [:email_automation_category])
    |> Repo.all()
  end

  def get_email_schedule_by_id(id) do
    from(es in EmailSchedule, where: es.id == ^id)
    |> Repo.one()
  end

  def update_email_schedule(id, params) do
    get_email_schedule_by_id(id)
    |> EmailSchedule.changeset(params)
    |> Repo.update()
  end

  defp filter_email_schedule(query, galleries, :gallery) do
    query
    |> join(:inner, [es, _, _], g in assoc(es, :gallery))
    |> where([es, _, _, _], es.gallery_id in ^galleries)
    |> select_merge([_, _, c, g], %{
      category_name: fragment("concat(?, ':', ?)", c.name, g.name),
      gallery_id: g.id
    })
    |> group_by([es, p, c, g], [c.name, g.name, c.type, c.id, p.id, es.id, g.id])
  end

  defp filter_email_schedule(query, job_id, _type) do
    query
    |> where([es, _, _], es.job_id == ^job_id)
    |> select_merge([_, _, c], %{category_name: c.name, gallery_id: nil})
    |> group_by([es, p, c], [c.name, c.type, c.id, p.id, es.id])
  end

  defp email_schedules_group_by_categories(emails_schedules) do
    emails_schedules
    |> Enum.group_by(&{&1.category_id, &1.category_name, &1.category_type, &1.gallery_id, &1.job_id})
    |> Enum.map(fn {{category_id, category_name, category_type, gallery_id, job_id}, group} ->
      pipelines =
        group
        |> Enum.group_by(& &1.pipeline["id"])
        |> Enum.map(fn {_pipeline_id, pipelines} ->
          emails =
            pipelines
            |> Enum.map(& &1.pipeline["email"])

          map = Map.delete(List.first(pipelines).pipeline, "email")
          Map.put(map, "emails", emails)
        end)

      pipeline_morphied = pipelines |> Enum.map(&(&1 |> Morphix.atomorphiform!()))

      %{
        category_id: category_id,
        category_name: category_name,
        category_type: category_type,
        gallery_id: gallery_id,
        job_id: job_id,
        pipelines: pipeline_morphied
      }
    end)
    |> Enum.sort_by(&{&1.category_id, &1.category_name}, :asc)
  end
end
