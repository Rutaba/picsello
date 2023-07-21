defmodule Picsello.EmailAutomationSchedules do
  @moduledoc """
    context module for email automation
  """
  import Ecto.Query

  alias Picsello.{
    Repo,
    EmailAutomations,
    EmailAutomation.EmailSchedule
  }

  def get_schedule_by_id(id) do
    from(es in EmailSchedule, where: es.id == ^id)
    |> Repo.one()
  end

  def get_schedules_by_gallery(gallery_id) do
    from(es in EmailSchedule, where: es.gallery_id == ^gallery_id)
    |> Repo.one()
  end

  def get_schedules_by_order(order_id) do
    from(es in EmailSchedule, where: es.order_id == ^order_id)
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
        join: s in assoc(p, :email_automation_sub_category),
        select: %{
          category_type: c.type,
          category_id: c.id,
          subcategory_slug: s.slug,
          subcategory_id: s.id,
          job_id: es.job_id,
          pipeline:
            fragment(
              "to_jsonb(json_build_object('id', ?, 'name', ?, 'state', ?, 'description', ?, 'email', ?))",
              p.id,
              p.name,
              p.state,
              p.description,
              fragment(
                "to_jsonb(json_build_object('id', ?, 'name', ?, 'total_hours', ?, 'condition', ?, 'body_template', ?, 'subject_template', ?, 'private_name', ?, 'is_stopped', ?, 'reminded_at', ?, 'order_id', ?, 'gallery_id', ?, 'job_id', ?))",
                es.id,
                es.name,
                es.total_hours,
                es.condition,
                es.body_template,
                es.private_name,
                es.private_name,
                es.is_stopped,
                es.reminded_at,
                es.order_id,
                es.gallery_id,
                es.job_id
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

  def update_email_schedule(id, params) do
    get_schedule_by_id(id)
    |> EmailSchedule.changeset(params)
    |> Repo.update()
  end

  defp filter_email_schedule(query, galleries, :gallery) do
    query
    |> join(:inner, [es, _, _, _], gallery in assoc(es, :gallery))
    |> join(:left, [es, _, _, _, gallery], order in assoc(es, :order))
    |> where([es, _, _, _, _, _], es.gallery_id in ^galleries)
    |> select_merge([es, _, c, s, gallery, order], %{
      category_name: fragment("concat(?, ':', ?)", c.name, gallery.name),
      gallery_id: gallery.id,
      order_id: es.order_id,
      order_number: order.number,
      subcategory_name: fragment("concat(?, ':', ?)", s.name, order.number)
    })
    |> group_by([es, p, c, s, gallery, order], [
      c.name,
      gallery.name,
      c.type,
      c.id,
      p.id,
      es.id,
      es.order_id,
      gallery.id,
      s.id,
      s.slug,
      s.name,
      order.number
    ])
  end

  defp filter_email_schedule(query, job_id, _type) do
    query
    |> where([es, _, _, _], es.job_id == ^job_id)
    |> select_merge([_, _, c, s], %{
      category_name: c.name,
      subcategory_name: s.name,
      gallery_id: nil,
      order_id: nil,
      order_number: ""
    })
    |> group_by([es, p, c, s], [c.name, c.type, c.id, p.id, es.id, s.id, s.slug, s.name])
  end

  defp email_schedules_group_by_categories(emails_schedules) do
    emails_schedules
    |> Enum.group_by(
      &{&1.subcategory_slug, &1.subcategory_name, &1.subcategory_id, &1.gallery_id, &1.job_id,
       &1.order_id, &1.order_number}
    )
    |> Enum.map(fn {{slug, name, id, gallery_id, job_id, order_id, order_number},
                    automation_pipelines} ->
      pipelines =
        automation_pipelines
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
        category_type: List.first(automation_pipelines).category_type,
        category_name: List.first(automation_pipelines).category_name,
        category_id: List.first(automation_pipelines).category_id,
        subcategory_slug: slug,
        subcategory_name: name,
        subcategory_id: id,
        gallery_id: gallery_id,
        job_id: job_id,
        order_id: order_id,
        order_number: order_number,
        pipelines: pipeline_morphied
      }
    end)
    |> Enum.sort_by(&{&1.subcategory_id, &1.subcategory_name}, :asc)
    |> Enum.group_by(
      &{&1.category_id, &1.category_name, &1.category_type, &1.gallery_id, &1.job_id}
    )
    |> Enum.map(fn {{id, name, type, gallery_id, job_id}, pipelines} ->
      subcategories = EmailAutomations.remove_categories_from_list(pipelines)

      %{
        category_type: type,
        category_name: name,
        category_id: id,
        gallery_id: gallery_id,
        job_id: job_id,
        subcategories: subcategories
      }
    end)
    |> Enum.sort_by(&{&1.category_id, &1.category_name}, :asc)
  end

  def query_get_email_schedule(category_type, gallery_id, job_id, piepline_id) do
    query =
      from(es in EmailSchedule,
        where: es.email_automation_pipeline_id == ^piepline_id,
        limit: 1
      )

    case category_type do
      :gallery -> query |> where([es], es.gallery_id == ^gallery_id)
      _ -> query |> where([es], es.job_id == ^job_id)
    end
  end

  def get_last_completed_email(category_type, gallery_id, job_id, pipeline_id) do
    query_get_email_schedule(category_type, gallery_id, job_id, pipeline_id)
    |> where([es], not is_nil(es.reminded_at))
    |> order_by([es], desc: es.id)
    |> Repo.one()
  end
end
