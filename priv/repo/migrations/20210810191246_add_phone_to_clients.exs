defmodule Picsello.Repo.Migrations.AddPhoneToClients do
  use Ecto.Migration

  def up do
    alter table(:clients) do
      add(:phone, :text)
    end

    execute("""
      update clients set phone = '(918) 555-1234';
    """)

    alter table(:clients) do
      modify(:phone, :text, null: false)
    end
  end

  def down do
    alter table(:clients) do
      remove(:phone)
    end
  end
end
