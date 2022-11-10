defmodule Picsello.Repo.Migrations.AddDurationMinutesInShoots do
  use Ecto.Migration
  def up do
    execute("""
      update shoots set duration_minutes = 15 from jobs where shoots.job_id = jobs.id and jobs.is_gallery_only = true;
    """)
  end
  def down do
    execute("""
      update shoots set duration_minutes = null from jobs where shoots.job_id = jobs.id and jobs.is_gallery_only = true;
    """)
  end
end
