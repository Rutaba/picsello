  defmodule Picsello.Repo.Migrations.AddAllowCashToUser do
    use Ecto.Migration
    def change do
      alter table(:users) do
        add(:allow_cash_payment, :boolean, null: false, default: false)
      end
      end
        end
