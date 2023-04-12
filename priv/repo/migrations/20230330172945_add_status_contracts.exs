defmodule Picsello.Repo.Migrations.AddStatusContracts do
  use Ecto.Migration

  def up do
    execute("CREATE TYPE contract_status AS ENUM ('active','archive')")

    alter table(:contracts) do
      add(:status, :contract_status, default: "active")
    end
  end

  def down do
    execute("""
      ALTER TABLE "public"."contracts"
      DROP COLUMN status
    """)

    execute("DROP TYPE contract_status")
  end
end
