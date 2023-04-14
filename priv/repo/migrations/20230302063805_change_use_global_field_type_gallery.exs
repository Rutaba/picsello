defmodule Picsello.Repo.Migrations.ChangeUseGlobalFieldTypeInGallery do
  use Ecto.Migration

  @default %{expiration: true, watermark: true, products: true, digital: true}

  def change do
    alter table(:galleries) do
      remove(:use_global)
      add(:use_global, :map, null: false, default: @default)
    end
  end
end