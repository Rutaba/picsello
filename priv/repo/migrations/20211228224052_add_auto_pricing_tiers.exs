defmodule Picsello.Repo.Migrations.AddAutoPricingTiers do
  use Ecto.Migration

  def change do
    execute(
      """
      insert into job_types (name, position) values
      ('wedding', 0),
      ('family', 1),
      ('newborn', 2),
      ('event', 3),
      ('portrait', 4),
      ('mini', 5),
      ('boudoir', 6),
      ('other', 7)
      on conflict (name) do update set position = excluded.position
      """,
      "delete from job_types where name in ('boudoir', 'mini')"
    )

    create table(:package_tiers, primary_key: false) do
      add(:name, :string, primary_key: true)
      add(:position, :integer, null: false)
    end

    create table(:package_base_prices) do
      add(:tier, references(:package_tiers, column: :name, type: :string))
      add(:job_type, references(:job_types, column: :name, type: :string))
      add(:full_time, :boolean, null: false)
      add(:min_years_experience, :integer, null: false)
      add(:base_price, :integer, null: false)
      add(:shoot_count, :integer, null: false)
      add(:download_count, :integer, null: false)
    end

    create(
      unique_index(:package_base_prices, [:tier, :job_type, :full_time, :min_years_experience])
    )

    create table(:cost_of_living_adjustments, primary_key: false) do
      add(:state, :string, primary_key: true)
      add(:multiplier, :decimal, null: false)
    end
  end
end
