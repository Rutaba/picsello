defmodule Picsello.Repo.Migrations.CreateNylasDetail do
  use Ecto.Migration

  def change do
    create table(:nylas_details) do
      add(:external_calendar_rw_id, :string)
      add(:external_calendar_read_list, {:array, :string})
      add(:oauth_token, :string)
      add(:account_id, :string)
      add(:previous_account_id, :string)
      add(:previous_oauth_token, :string)
      add(:user_id, references(:users, on_delete: :nothing), null: false)

      timestamps()
    end

    execute(
      """
        insert into nylas_details (user_id, inserted_at, updated_at)
        select users.id, now(), now()
        from users
      """,
      ""
    )
  end
end
