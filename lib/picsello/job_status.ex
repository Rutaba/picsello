defmodule Picsello.JobStatus do
  @moduledoc false

  use Ecto.Schema
  alias Picsello.{Job}

  @primary_key false
  schema "job_statuses" do
    field(:current_status, Ecto.Enum,
      values:
        ~w[accepted answered archived completed deposit_paid not_sent sent signed_with_questionnaire signed_without_questionnaire imported]a
    )

    field(:changed_at, :utc_datetime)
    field(:is_lead, :boolean)
    belongs_to(:job, Job)
  end
end
