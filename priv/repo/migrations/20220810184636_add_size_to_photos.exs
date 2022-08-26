defmodule Picsello.Repo.Migrations.AddSizeToPhoto do
  use Ecto.Migration

  def change do
    alter table(:photos) do
      add(:size, :integer)
    end
  end
end
