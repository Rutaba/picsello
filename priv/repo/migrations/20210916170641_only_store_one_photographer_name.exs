defmodule Picsello.Repo.Migrations.OnlyStoreOnePhotographerName do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove(:last_name, :string)
    end

    rename(table(:users), :first_name, to: :name)
  end
end
