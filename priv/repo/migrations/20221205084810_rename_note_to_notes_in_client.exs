defmodule Picsello.Repo.Migrations.RenameNoteToNotesInClient do
  use Ecto.Migration

  def change do
    rename(table(:clients), :note, to: :notes)
  end
end
