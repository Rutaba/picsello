defmodule Picsello.Repo.Migrations.AddStoppedReasonInEmailSchedules do
  use Ecto.Migration

  @type_name "stopped_reason_type"

  def change do
    execute(
      "CREATE TYPE #{@type_name} AS ENUM ('photographer_stopped','proposal_accepted')",
      "DROP TYPE #{@type_name}"
    )

    alter table(:email_schedules) do
      add(:stopped_reason, :"#{@type_name}")
    end
  end
end
