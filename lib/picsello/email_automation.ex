defmodule Picsello.EmailAutomation do
  @moduledoc """
    context module for email automation
  """
  import Ecto.Query

  alias Picsello.{Repo, EmailPresets.EmailPreset}

  alias Picsello.EmailAutomation.{
    EmailAutomationPipeline,
    EmailAutomationType
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
            "array_agg(to_jsonb(json_build_object('id', ?, 'name', ?, 'status', ?, 'state', ?, 'description', ?)))",
            p.id,
            p.name,
            p.status,
            p.state,
            p.description
          )
      },
      group_by: [c.name, c.type, c.id, s.slug, s.name, s.id, p.id],
      order_by: [asc: p.id, asc: c.type, asc: s.slug]
    )
    |> Repo.all()
  end

  def get_pipeline_by_id(id) do
    from(eap in EmailAutomationPipeline, where: eap.id == ^id)
    |> Repo.one()
  end

  def get_each_pipeline_emails(pipeline_id, organization_id, job_type_id) do
    from(
      ep in EmailPreset,
      join: es in assoc(ep, :email_automation_setting),
      on: ep.email_automation_setting_id == es.id,
      left_join: type in EmailAutomationType,
      on: type.email_preset_id == ep.id,
      where:
        es.email_automation_pipeline_id == ^pipeline_id and es.organization_id == ^organization_id,
      where: type.organization_job_id == ^job_type_id,
      order_by: [asc: ep.id, asc: es.id],
      preload: [:email_automation_setting]
    )
    |> Picsello.Repo.all()
  end

  def get_email_by_id(id) do
    from(
      ep in EmailPreset,
      join: es in assoc(ep, :email_automation_setting),
      on: ep.email_automation_setting_id == es.id,
      where: es.id == ^id,
      preload: [:email_automation_setting]
    )
    |> Repo.one()
  end

  def get_all_pipelines_emails(organization_id, job_type_id) do
    get_all_pipelines()
    |> Enum.map(fn %{pipelines: pipelines} = automation ->
      updated_pipelines =
        Enum.map(pipelines, fn pipeline ->
          pipeline_morphed = pipeline |> Morphix.atomorphiform!()
          pipeline_id = Map.get(pipeline_morphed, :id)
          emails_data = get_each_pipeline_emails(pipeline_id, organization_id, job_type_id)
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
end

# Picsello.EmailAutomation.get_all_pipelines_emails(1,1)
