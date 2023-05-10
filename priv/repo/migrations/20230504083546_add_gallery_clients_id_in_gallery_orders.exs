defmodule Picsello.Repo.Migrations.AddGalleryClientsIdInGalleryOrders do
  use Ecto.Migration

  alias Picsello.{Repo, Cart.Order}

  @table "gallery_orders"
  def up do
    alter(table(@table)) do
      add(:gallery_client_id, references(:gallery_clients, on_delete: :nothing))
    end
  end

  def down do
    alter(table(@table)) do
      remove(:gallery_client_id, references(:gallery_client, on_delete: :nothing))
    end
  end
end
