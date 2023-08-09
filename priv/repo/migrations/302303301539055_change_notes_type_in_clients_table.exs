defmodule Picsello.Repo.Migrations.ChangeNotesTypeInClientsTable do
  use Ecto.Migration

  def change do
    alter table(:clients) do
      modify(:notes, :text, from: :string)
    end
  end
end
