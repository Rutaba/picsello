defmodule Picsello.Repo.Migrations.AddColumnToCategoryTemplate do
  use Ecto.Migration

  def up do
    alter table("category_templates") do
      add(:title, :text)
    end
  end
end
