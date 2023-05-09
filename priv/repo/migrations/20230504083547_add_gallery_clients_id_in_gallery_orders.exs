defmodule Picsello.Repo.Migrations.AddGalleryClientsIdInGalleryOrders do
  use Ecto.Migration

  alias Picsello.{Repo, Cart.Order}

  @table "gallery_orders"
  def up do
    orders =
      Order
      |> Repo.all()
      |> Repo.preload(gallery: [job: :client])

    Enum.map(orders, fn order ->
      execute("""
        insert into gallery_clients (gallery_id, email, inserted_at, updated_at) values (#{order.gallery_id}, '#{order.gallery.job.client.email}', now(), now());
      """)
    end)

    alter(table(@table)) do
      add(:gallery_client_id, references(:gallery_clients, on_delete: :nothing))
    end

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

  def down do
    alter(table(@table)) do
      remove(:gallery_client_id, references(:gallery_client, on_delete: :nothing))
    end
  end
end
