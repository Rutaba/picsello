defmodule Picsello.Repo.Migrations.AddOutboundToClientMessages do
  use Ecto.Migration

  def up do
    alter table(:client_messages) do
      add(:outbound, :boolean)
    end

    execute("""
      update client_messages set outbound = true;
    """)

    alter table(:client_messages) do
      modify(:outbound, :boolean, null: false)
    end
  end

  def down do
    alter table(:client_messages) do
      remove(:outbound, :boolean)
    end
  end
end
