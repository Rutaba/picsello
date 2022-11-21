defmodule Picsello.Repo.Migrations.AddGlobalColumn do
  use Ecto.Migration

  def change do
    alter table(:cards) do
      add(:is_global, :boolean, default: false)
    end
  end
end
