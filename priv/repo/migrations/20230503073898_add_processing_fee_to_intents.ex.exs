defmodule Picsello.Repo.Migrations.AddProcessingFeeToIntents do
  use Ecto.Migration

  def change do
    alter table(:gallery_order_intents) do
      add(:processing_fee, :integer)
    end
  end
end
