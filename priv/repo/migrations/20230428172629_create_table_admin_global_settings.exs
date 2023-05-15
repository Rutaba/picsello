defmodule Picsello.Repo.Migrations.CreateTableAdminGlobalSettings do
  use Ecto.Migration
  
  @table :admin_global_settings
  @type_name "AGS_status_type"

  def change do
    execute("CREATE TYPE #{@type_name} AS ENUM ('active','disabled','archived')", "DROP TYPE #{@type_name}")

    create table(@table) do
      add(:title, :string, null: false)
      add(:description, :string, null: false)
      add(:slug, :string, null: false)
      add(:value, :string, null: false)
      add(:status, :"#{@type_name}", null: false)

      timestamps()
    end

    create(unique_index(@table, [:slug]))
    
    execute("""
    INSERT INTO admin_global_settings VALUES (1, 'Free Trial', 'free trial in days', 'free_trial', '14', 'active', now(), now());
  """)
  end
end
