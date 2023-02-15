defmodule Picsello.Repo.Migrations.AddBccAndToEmailToClientMessage do
  use Ecto.Migration

  def up do
    alter table(:client_messages) do
      remove_if_exists(:cc_email, :string)
      add_if_not_exists(:cc_email, {:array, :string}, null: true)
      add_if_not_exists(:bcc_email, {:array, :string}, null: true)
      add_if_not_exists(:to_email, {:array, :string}, null: false, default: [])
    end

    execute("""
      update client_messages set to_email = array_append(to_email, clients.email) from clients where clients.id = client_messages.client_id;
    """)
  end

  def down do
    alter table(:client_messages) do
      remove_if_exists(:cc_email, {:array, :string})
      add_if_not_exists(:cc_email, :string, null: true)
      remove_if_exists(:bcc_email, {:array, :string})
      remove_if_exists(:to_email, {:array, :string})
    end
  end
end
