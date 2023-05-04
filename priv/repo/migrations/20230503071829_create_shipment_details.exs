defmodule Picsello.Repo.Migrations.CreateShipmentDetails do
  use Ecto.Migration

  def change do
    create table(:shipment_details) do
      add(:type, :string)
      add(:base_charge, :integer)
      add(:order_attribute_id, :integer)
      add(:das_carrier, :string)
      add(:upcharge, :map)

      timestamps()
    end

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    execute(
      """
      INSERT INTO shipment_details (type, base_charge, order_attribute_id, das_carrier, upcharge, inserted_at, updated_at) VALUES
      ('economy_usps', 410, 545, 'mail', '{"default": 5.0}', '#{now}', '#{now}'),
      ('economy_trackable', 1045, 546, 'parcel', '{"default": 9.0, "wallart": 9.0}', '#{now}', '#{now}'),
      ('three_days', 1395, 100, 'parcel', '{"default": 11.0, "wallart": 16.0}', '#{now}', '#{now}'),
      ('one_day', 2595, 1728, 'parcel', '{"default": 16.0, "wallart": 26.0}', '#{now}', '#{now}')
      ;
      """,
      ""
    )
  end
end
