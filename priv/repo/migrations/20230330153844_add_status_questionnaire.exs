defmodule Picsello.Repo.Migrations.AddStatusQuestionnaire do
  use Ecto.Migration

  def up do
    execute("CREATE TYPE questionnaire_status AS ENUM ('active','archive')")

    alter table(:questionnaires) do
      add(:status, :questionnaire_status, default: "active")
    end
  end

  def down do
    execute("""
      ALTER TABLE "public"."questionnaires"
      DROP COLUMN status
    """)

    execute("DROP TYPE questionnaire_status")
  end
end
