defmodule Picsello.Repo.Migrations.RemoveProposalIdFromClientMessages do
  use Ecto.Migration

  def up do
    drop(constraint("client_messages", "must_reference_job_or_proposal"))

    execute("""
     update client_messages set job_id = booking_proposals.job_id from booking_proposals
     where booking_proposals.id = proposal_id and proposal_id is not null;
    """)

    alter table(:client_messages) do
      modify(:job_id, :bigint, null: false)
      remove(:proposal_id)
    end
  end

  def down do
    alter table(:client_messages) do
      modify(:job_id, :bigint, null: true)
      add(:proposal_id, references(:booking_proposals))
    end

    create(
      constraint("client_messages", "must_reference_job_or_proposal",
        check: "((proposal_id is not null)::integer + (job_id is not null)::integer) = 1"
      )
    )
  end
end
