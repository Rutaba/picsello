defmodule Picsello.Repo.Migrations.PaymentTypes do
  use Ecto.Migration

  def up do
    alter table(:organizations) do
      add(:payment_options, :map,
        default: %{
          allow_cash: false,
          allow_affirm: false,
          allow_afterpay_clearpay: false,
          allow_klarna: false,
          allow_cashapp: false
        }
      )
    end

    execute("""
      UPDATE organizations
      SET payment_options = JSONB_BUILD_OBJECT('allow_cash', users.allow_cash_payment::BOOLEAN)
      FROM users
      WHERE organizations.id = users.id;
    """)

    alter table(:users) do
      remove(:allow_cash_payment)
    end
  end

  def down do
    alter table(:users) do
      add(:allow_cash_payment, :boolean, default: false)
    end

    execute("""
      UPDATE users
      SET allow_cash_payment = organizations.payment_options->>'allow_cash'
      FROM organizations
      WHERE users.id = organizations.id;
    """)

    alter table(:organizations) do
      remove(:payment_options)
    end
  end
end
