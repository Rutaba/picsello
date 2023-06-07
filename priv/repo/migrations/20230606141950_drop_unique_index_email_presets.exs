defmodule Picsello.Repo.Migrations.DropUniqueIndexEmailPresets do
  use Ecto.Migration

  def up do
    # alter table(:email_presets) do
    #   drop index(:email_presets, [:name])
    #   drop index(:email_presets, [:job_type], name: :job_must_have_job_type)
    # end
  end

  def down do
    # create(unique_index(:email_presets, [:job_type, :name]))
  end
end
