defmodule Picsello.Repo.Migrations.DefaultMarkupSumTerm do
  use Ecto.Migration

  def change do
    execute(
      """
      alter table categories alter column default_markup set default 1.0
      """,
      """
      alter table categories alter column default_markup set default 2.0
      """
    )
  end
end
