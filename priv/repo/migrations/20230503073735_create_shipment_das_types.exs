defmodule Picsello.Repo.Migrations.CreateShipmentDasTypes do
  use Ecto.Migration

  def change do
    create table(:shipment_das_types) do
      add(:name, :string)
      add(:parcel_cost, :decimal)
      add(:mail_cost, :decimal)

      timestamps()
    end

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    execute(
      """
        INSERT INTO shipment_das_types (name, parcel_cost, mail_cost, inserted_at, updated_at) VALUES
        ('DAS', 4.17, 0.40, '#{now}', '#{now}'),
        ('DAS Extended', 5.37, 0.51, '#{now}', '#{now}'),
        ('DAS Remote', 9.94, 0.95, '#{now}', '#{now}'),
        ('DAS Hawaii', 9.00, 0.86, '#{now}', '#{now}'),
        ('DAS Alaska', 28.50, 2.71, '#{now}', '#{now}')
        ;
      """,
      ""
    )
  end
end
