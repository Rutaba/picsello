defmodule Picsello.Repo.Migrations.CreateShipmentDasTypes do
  use Ecto.Migration

  def change do
    create table(:shipment_das_types) do
      add(:name, :string)
      add(:parcel_cost, :integer)
      add(:mail_cost, :integer)

      timestamps()
    end

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    execute(
      """
        INSERT INTO shipment_das_types (name, parcel_cost, mail_cost, inserted_at, updated_at) VALUES
        ('DAS', 417, 40, '#{now}', '#{now}'),
        ('DAS Extended', 537, 51, '#{now}', '#{now}'),
        ('DAS Remote', 994, 95, '#{now}', '#{now}'),
        ('DAS Hawaii', 900, 86, '#{now}', '#{now}'),
        ('DAS Alaska', 2850, 271, '#{now}', '#{now}')
        ;
      """,
      ""
    )
  end
end
