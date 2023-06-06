defmodule Picsello.Repo.Migrations.DropUniqueIndexEmailPresets do
  use Ecto.Migration

  def up do
    # alter table(:email_presets) do
      # drop index(:email_presets, [:name])
      # drop constraint(:email_presets, "job_must_have_job_type")
      # drop index(:email_presets, [:job_type])
      # # drop index("foo", [:bar_id], name: :bar_pending_index)
    # end
  end

  def down do
    # create(unique_index(:email_presets, [:job_type, :name]))
  end
end
