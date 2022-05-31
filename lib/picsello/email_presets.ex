defmodule Picsello.EmailPresets do
  @moduledoc """
  Context to handle email presets
  """
  import Ecto.Query
  import Picsello.Repo.CustomMacros

  alias Picsello.{Repo, Job, Shoot, EmailPreset, EmailPresets.JobResolver}

  def for({:booking_proposal, job_type}) do
    from(preset in job_presets(),
      where: preset.job_type == ^job_type and preset.job_state == :booking_proposal
    )
    |> Repo.all()
  end

  def for(%Job{type: job_type} = job) do
    job = job |> Repo.preload(:job_status)

    from(
      preset in job_presets(),
      where: preset.job_type == ^job_type,
      order_by: :position
    )
    |> for_job(job)
    |> Repo.all()
  end

  defp for_job(query, %Job{job_status: %{is_lead: true}}) do
    query |> where([preset], preset.job_state == :lead)
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
        (preset.job_state == :job and shoot.past_count == 0) or
          (preset.job_state == :post_shoot and shoot.past_count > 0)
    )
  end

  defp job_presets(), do: from(preset in EmailPreset, where: preset.type == :job)

  def resolve_variables(%EmailPreset{} = preset, %Job{} = job, helpers) do
    data = job |> JobResolver.new(helpers) |> JobResolver.to_map()

    %{
      preset
      | body_template: render(preset.body_template, data),
        subject_template: render(preset.subject_template, data)
    }
  end

  defp render(template, data),
    do: :bbmustache.render(template, data, key_type: :binary, value_serializer: &to_string/1)
end
