defmodule Picsello.Repo.Migrations.ConvertProposalMessagesToClientMessages do
  use Ecto.Migration

  def up do
    rename(table("proposal_messages"), to: table("client_messages"))

    alter table("client_messages") do
      modify(:proposal_id, :bigint, null: true)
      add(:job_id, references("jobs"))
    end

    create(index(:client_messages, [:job_id]))

    create(
      constraint("client_messages", "must_reference_job_or_proposal",
        check: "((proposal_id is not null)::integer + (job_id is not null)::integer) = 1"
      )
    )
  end

  def down do
    drop(constraint("client_messages", "must_reference_job_or_proposal"))

    alter table("client_messages") do
      modify(:proposal_id, :bigint, null: false)
      remove(:job_id)
    end

    rename(table("client_messages"), to: table("proposal_messages"))
  end
end
