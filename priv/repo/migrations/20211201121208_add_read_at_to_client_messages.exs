defmodule Picsello.Repo.Migrations.AddReadAtToClientMessages do
  use Ecto.Migration

  def change do
    alter table(:client_messages) do
      add(:read_at, :utc_datetime)
    end

    execute(
      """
      update client_messages set read_at = now();
      """,
      ""
    )
  end
end
