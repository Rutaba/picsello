defmodule Picsello.Repo.Migrations.CreateContracts do
  use Ecto.Migration

  def change do
    create table(:contracts) do
      add :name, :string, null: false
      add :content, :text, null: false
      add :organization_id, references(:organizations, on_delete: :nothing), null: false
      add :job_type, references(:job_types, column: :name, type: :string)
      add :contract_template_id, references(:contracts, on_delete: :nothing)

      timestamps()
    end

    # contract_template_id job_type
    # 1                     1    =  invalid -- cannot both *be* a template and *have* a template
    # 1                     0    =  valid -- contract from template
    # 0                     1    =  valid -- contract template
    # 0                     0    =  invalid -- 1 off contract without template are not allowed
    create(
      constraint("contracts", "contracts_must_have_types",
        check:
          "((contract_template_id is not null)::integer + (job_type is not null)::integer) = 1"
      )
    )

    create index(:contracts, [:organization_id])

    create unique_index(:contracts, [:name, :organization_id],
             where: "contract_template_id is null"
           )

    alter table(:jobs) do
      add(:contract_id, references(:contracts, on_delete: :nothing))
    end

    create(index(:jobs, [:contract_id]))
  end
end
