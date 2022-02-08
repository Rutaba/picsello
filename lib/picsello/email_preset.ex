defmodule Picsello.EmailPreset do
  @moduledoc "options for pre-written emails"
  use Ecto.Schema

  import Ecto.Query, only: [from: 2]
  import Picsello.Repo.CustomMacros

  @job_states ~w(post_shoot job lead)a

  schema "email_presets" do
    field :body_template, :string
    field :job_state, Ecto.Enum, values: @job_states
    field :job_type, :string
    field :name, :string
    field :subject_template, :string

    timestamps type: :utc_datetime
  end

  def job_states(), do: @job_states

  def for_job(%{id: job_id}) do
    from(preset in __MODULE__,
      join: job in Picsello.Job,
      on: job.type == preset.job_type and job.id == ^job_id,
      join: status in assoc(job, :job_status),
      join:
        shoot in subquery(
          from(
            shoot in Picsello.Shoot,
            where: shoot.starts_at <= now() and shoot.job_id == ^job_id,
            select: %{past_count: count(shoot.id)}
          )
        ),
      on: true,
      where:
        (status.is_lead and preset.job_state == :lead) or
          (not status.is_lead and
             ((preset.job_state == :job and shoot.past_count == 0) or
                (preset.job_state == :post_shoot and shoot.past_count > 0)))
    )
    |> Picsello.Repo.all()
  end
end
