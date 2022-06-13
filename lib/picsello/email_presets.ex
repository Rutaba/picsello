defmodule Picsello.EmailPresets do
  @moduledoc """
  Context to handle email presets
  """
  import Ecto.Query
  import Picsello.Repo.CustomMacros

  alias Picsello.{Repo, Job, Shoot, EmailPresets.EmailPreset, Galleries.Gallery}

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

  defp for_job(query, %Job{job_status: %{is_lead: true}}) do
    query |> where([preset], preset.state == :lead)
  end

  defp for_job(query, %Job{job_status: %{is_lead: false}, id: job_id}) do
    from(preset in query,
      join: job in Job,
      on: job.type == preset.job_type and job.id == ^job_id,
      join: status in assoc(job, :job_status),
      join:
        shoot in subquery(
          from(shoot in Shoot,
            where: shoot.starts_at <= now() and shoot.job_id == ^job_id,
            select: %{past_count: count(shoot.id)}
          )
        ),
      on: true,
      where:
        (preset.state == :job and shoot.past_count == 0) or
          (preset.state == :post_shoot and shoot.past_count > 0)
    )
  end

  defp job_presets(),
    do: from(preset in EmailPreset, where: preset.type == :job, order_by: :position)

  defp gallery_presets(),
    do: from(preset in EmailPreset, where: preset.type == :gallery, order_by: :position)

  def resolve_variables(%EmailPreset{} = preset, schemas, helpers) do
    resolver_module =
      case preset.type do
        :job -> Picsello.EmailPresets.JobResolver
        :gallery -> Picsello.EmailPresets.GalleryResolver
      end

    resolver = schemas |> resolver_module.new(helpers)

    data =
      for {key, func} <- resolver_module.vars(), into: %{} do
        {key, func.(resolver)}
      end

    %{
      preset
      | body_template: render(preset.body_template, data),
        subject_template: render(preset.subject_template, data)
    }
  end

  defp render(template, data),
    do: :bbmustache.render(template, data, key_type: :binary, value_serializer: &to_string/1)
end
