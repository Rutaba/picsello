defmodule Picsello.Repo.Migrations.InsertGalleryClientsForPhotographers do
  use Ecto.Migration

  def up do
      execute("""
        insert into gallery_clients (gallery_id, email, inserted_at, updated_at)
        select g.id, u.email, now(), now()
        from galleries g
        join jobs j on j.id = g.job_id
        join clients c on c.id = j.client_id
        join users u on u.organization_id = c.organization_id
      """)
  end
end
