defmodule Picsello.EmailAutomation do
  @moduledoc """
    context module for email automation
  """
  import Ecto.Query

  alias Picsello.{Repo, EmailPresets.EmailPreset}

  alias Picsello.EmailAutomation.{
    EmailAutomationPipeline,
    EmailSchedule
  }

  def get_all_pipelines() do
    from(
      p in EmailAutomationPipeline,
      join: c in assoc(p, :email_automation_category),
      join: s in assoc(p, :email_automation_sub_category),
      select: %{
        category_type: c.type,
        category_name: c.name,
        category_id: c.id,
        subcategory_slug: s.slug,
        subcategory_name: s.name,
        subcategory_id: s.id,
        pipelines:
          fragment(
            "array_agg(to_jsonb(json_build_object('id', ?, 'name', ?, 'state', ?, 'description', ?)))",
            p.id,
            p.name,
            p.state,
            p.description
          )
      },
      group_by: [c.name, c.type, c.id, s.slug, s.name, s.id, p.id],
      order_by: [asc: p.id, asc: c.type, asc: s.slug]
    )
    |> Repo.all()
  end

  def get_pipelines(organization_id, job_type) do
    email_query = subquery_email(organization_id, job_type)

    from(eap in EmailAutomationPipeline)
    |> preload([
      :email_automation_category,
      :email_automation_sub_category,
      {:email_presets, ^email_query}
    ])
    |> Repo.all()
  end

  def get_emails_schedules_galleries(galleries) do
    from(
      es in EmailSchedule,
      join: p in assoc(es, :email_automation_pipeline),
      join: c in assoc(p, :email_automation_category),
      join: g in assoc(es, :gallery),
      on: es.gallery_id == g.id,
      where: es.gallery_id in ^galleries,
      select: %{
        category_type: c.type,
        category_name: fragment("concat(?, ':', ?)", c.name, g.name),
        category_id: c.id,
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
      },
      group_by: [c.name, g.name, c.type, c.id, p.id, es.id]
    )
    |> Repo.all()
    |> email_schedules_group_by_categories()
  end

  def get_emails_schedules_jobs(job_id) do
    from(
      es in EmailSchedule,
      join: p in assoc(es, :email_automation_pipeline),
      join: c in assoc(p, :email_automation_category),
      where: es.job_id == ^job_id,
      select: %{
        category_type: c.type,
        category_name: c.name,
        category_id: c.id,
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
      },
      group_by: [c.name, c.type, c.id, p.id, es.id]
    )
    |> Repo.all()
    |> email_schedules_group_by_categories()
  end

  defp email_schedules_group_by_categories(emails_schedules) do
    emails_schedules
    |> Enum.group_by(&{&1.category_id, &1.category_name, &1.category_type})
    |> Enum.map(fn {{category_id, category_name, category_type}, group} ->
      pipelines =
        group
        |> Enum.group_by(& &1.pipeline["id"])
        |> Enum.map(fn {pipeline_id, pipelines} ->
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
        pipelines: pipeline_morphied
      }
    end)
    |> Enum.sort_by(&{&1.category_id, &1.category_name}, :asc)
  end

  def subquery_email(organization_id, job_type) do
    from(
      ep in EmailPreset,
      where: ep.organization_id == ^organization_id,
      where: ep.job_type == ^job_type
    )
  end

  def get_emails_for_schedule(organization_id, job_type, types \\ [:lead]) do
    get_pipelines(organization_id, job_type)
    |> Enum.flat_map(fn pipeline ->
      if pipeline.email_automation_category.type in types do
        pipeline.email_presets
        |> Enum.map(
          &[
            email_automation_pipeline_id: pipeline.id,
            total_hours: &1.total_hours,
            condition: &1.condition,
            body_template: &1.body_template,
            subject_template: &1.subject_template,
            name: &1.name
          ]
        )
      else
        []
      end
    end)
  end

  def get_pipeline_by_id(id) do
    from(eap in EmailAutomationPipeline, where: eap.id == ^id)
    |> Repo.one()
  end

  def update_pipeline_and_settings_status(pipeline_id, active) do
    status = toggle_status(active)

    from(es in EmailPreset,
      where: es.email_automation_pipeline_id == ^pipeline_id,
      update: [set: [status: ^status]]
    )
    |> Repo.update_all([])
  end

  def delete_email(email_preset_id) do
    from(p in EmailPreset,
      where: p.id == ^email_preset_id
    )
    |> Repo.one()
    |> Repo.delete()
  end

  def get_each_pipeline_emails(pipeline_id, organization_id, job_type) do
    from(
      ep in EmailPreset,
      where:
        ep.email_automation_pipeline_id == ^pipeline_id and ep.organization_id == ^organization_id,
      where: ep.job_type == ^job_type,
      order_by: [asc: ep.id]
    )
    |> Picsello.Repo.all()
  end

  def get_email_by_id(id) do
    from(
      ep in EmailPreset,
      where: ep.id == ^id
    )
    |> Repo.one()
  end

  def get_all_pipelines_emails(organization_id, job_type) do
    get_all_pipelines()
    |> Enum.map(fn %{pipelines: pipelines} = automation ->
      updated_pipelines =
        Enum.map(pipelines, fn pipeline ->
          pipeline_morphed = pipeline |> Morphix.atomorphiform!()
          pipeline_id = Map.get(pipeline_morphed, :id)
          emails_data = get_each_pipeline_emails(pipeline_id, organization_id, job_type)
          # Update pipeline struct with email data
          Map.put(pipeline_morphed, :emails, emails_data)
        end)

      Map.put(automation, :pipelines, updated_pipelines)
    end)
    |> group_by_sub_category()
  end

  def group_by_sub_category(automation_pipelines) do
    automation_pipelines
    |> Enum.group_by(&{&1.subcategory_slug, &1.subcategory_name, &1.subcategory_id})
    |> Enum.map(fn {{slug, name, id}, automation_pipelines} ->
      %{
        category_type: List.first(automation_pipelines).category_type,
        category_name: List.first(automation_pipelines).category_name,
        category_id: List.first(automation_pipelines).category_id,
        subcategory_slug: slug,
        subcategory_name: name,
        subcategory_id: id,
        pipelines: automation_pipelines |> Enum.flat_map(& &1.pipelines)
      }
    end)
    |> Enum.sort_by(& &1.subcategory_id, :asc)
    |> Enum.group_by(&{&1.category_type, &1.category_name, &1.category_id}, & &1)
    |> Enum.map(fn {{type, name, id}, pipelines} ->
      subcategories = remove_categories_from_list(pipelines)
      %{category_type: type, category_name: name, category_id: id, subcategories: subcategories}
    end)
    |> Enum.sort_by(& &1.category_type, :desc)
  end

  defp remove_categories_from_list(sub_categories) do
    Enum.map(sub_categories, fn sub_category ->
      sub_category
      |> Map.take([:pipelines, :subcategory_id, :subcategory_slug, :subcategory_name])
    end)
  end

  defp toggle_status("true"), do: "disabled"
  defp toggle_status("false"), do: "active"
end
