defmodule Picsello.Repo.Migrations.AddEmailPresets do
  use Ecto.Migration

  def change do
    create table(:email_presets) do
      add(:job_type, references(:job_types, column: :name, type: :string), null: false)
      add(:body_template, :text, null: false)
      add(:subject_template, :text, null: false)
      add(:job_state, :text, null: false)
      add(:name, :text, null: false)
      add(:position, :integer, null: false)

      timestamps()
    end

    create(unique_index(:email_presets, ~w[job_type job_state name]a))
  end
end
