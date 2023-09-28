defmodule Picsello.Repo.Migrations.CreateUserCurrencyTable do
  use Ecto.Migration

  def up do
    # create table(:user_currencies) do
    # add(:previous_currency, :string, default: "USD", null: false)
    # add(:exchange_rate, :float, default: 1.00, null: false)

    # add(:currency, references(:currencies, type: :string, column: :code), default: "USD")
    # add(:organization_id, references(:organizations))

    # timestamps()
    # end

    # execute("""
    #   insert into user_currencies (organization_id, inserted_at, updated_at)
    #   select o.id, now(), now()
    #   from organizations o
    # """)
  end

  def down do
    drop(table(:user_currencies))
  end
end
