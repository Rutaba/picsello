defmodule Picsello.Repo.Migrations.AddGalleryClientsIdInGalleryOrders do
  use Ecto.Migration

  alias Picsello.{Repo, Cart.Order}

  @table "gallery_orders"
  def up do
      execute("""
        insert into gallery_clients (gallery_id, email, inserted_at, updated_at)
        select o.gallery_id, c.email, now(), now()
        from gallery_orders o join galleries g on g.id = o.gallery_id
        join jobs j on j.id = g.job_id
        join clients c on c.id = j.client_id
      """)

    execute("""
      update #{@table} set gallery_client_id = gallery_clients.id from gallery_clients where gallery_orders.gallery_id = gallery_clients.gallery_id;
    """)

    execute(
      "ALTER TABLE #{@table} DROP CONSTRAINT IF EXISTS gallery_orders_gallery_client_id_fkey"
    )

    alter(table(@table)) do
      modify(:gallery_client_id, references(:gallery_clients, on_delete: :nothing), null: false)
    end
  end
end
