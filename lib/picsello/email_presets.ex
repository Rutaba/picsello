defmodule Picsello.EmailPresets do
  @moduledoc """
  Context to handle email presets
  """
  import Ecto.Query
  import Picsello.Repo.CustomMacros

  alias Picsello.{Repo, Job, Shoot, EmailPresets.EmailPreset, Utils}
  alias Picsello.Galleries.Gallery
  alias Picsello.EmailAutomation.{EmailAutomationPipeline}

  def email_automation_presets(type) do
    from(p in presets(type), where: is_nil(p.email_automation_pipeline_id) and is_nil(p.job_type))
    |> Repo.all()
  end

  def for(%Gallery{}, state) do
    from(preset in gallery_presets(), where: preset.state == ^state)
    |> Repo.all()
  end

  def for(%Job{type: job_type}, state) do
    from(preset in job_presets(), where: preset.job_type == ^job_type and preset.state == ^state)
    |> Repo.all()
  end

  def for(%Job{type: job_type} = job) do
    job = job |> Repo.preload(:job_status)

    from(
      preset in job_presets(),
      where: preset.job_type == ^job_type
    )
    |> for_job(job)
    |> Repo.all()
  end

  defp for_job(query, %Job{
         job_status: %{is_lead: true, current_status: current_status},
         id: job_id
       }) do
    state = if current_status == :not_sent, do: :lead, else: :booking_proposal_sent

    from(preset in query,
      join: job in Job,
      on: job.type == preset.job_type and job.id == ^job_id,
      join: p in EmailAutomationPipeline,
      on: preset.email_automation_pipeline_id == p.id,
      where: p.state == ^state
    )
  end

  defp for_job(query, %Job{job_status: %{is_lead: false}, id: job_id}) do
    from(preset in query,
      join: job in Job,
      on: job.type == preset.job_type and job.id == ^job_id,
      join: p in EmailAutomationPipeline,
      on: preset.email_automation_pipeline_id == p.id,
      join:
        shoot in subquery(
          from(shoot in Shoot,
            where: shoot.starts_at <= now() and shoot.job_id == ^job_id,
            select: %{past_count: count(shoot.id)}
          )
        ),
      on: true,
      where:
        (p.state == :job and shoot.past_count == 0) or
          (p.state == :post_shoot and shoot.past_count > 0)
    )
  end

  defp job_presets(), do: presets(:job)

  defp gallery_presets(), do: presets(:gallery)

  defp presets(type),
    do: from(preset in EmailPreset, where: preset.type == ^type, order_by: :position)

  def resolve_variables(%EmailPreset{} = preset, schemas, helpers) do
    resolver_module =
      case preset.type do
        :job -> Picsello.EmailPresets.JobResolver
        _ -> Picsello.EmailPresets.GalleryResolver
      end

    resolver = schemas |> resolver_module.new(helpers)

    data =
      for {key, func} <- resolver_module.vars(), into: %{} do
        {key, func.(resolver)}
      end

    %{
      preset
      | body_template: Utils.render(preset.body_template, data),
        subject_template: Utils.render(preset.subject_template, data)
    }
  end
end
