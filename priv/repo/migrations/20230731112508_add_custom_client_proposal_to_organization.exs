defmodule Picsello.Repo.Migrations.AddCustomClientProposalToOrganization do
  use Ecto.Migration
  # TODO: move it to a separate table
  def up do
    alter table("organizations") do
      add(:client_proposal, :map, default: nil)
    end
  end

  def down do
    alter table("organizations") do
      remove(:client_proposal)
    end
  end
end
