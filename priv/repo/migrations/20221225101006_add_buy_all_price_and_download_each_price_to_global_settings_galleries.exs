defmodule Picsello.Repo.Migrations.AddBuyAllPriceAndDownloadEachPriceToGlobalSettingsGalleries do
  use Ecto.Migration

  def change do
    alter table(:global_settings_galleries) do
      add(:buy_all_price, :integer)
      add(:download_each_price, :integer)
    end
  end
end
