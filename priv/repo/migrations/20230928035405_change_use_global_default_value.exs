defmodule Picsello.Repo.Migrations.ChangeUseGlobalDefaultValue do
  use Ecto.Migration

  @default %{products: true}

  def change do
    alter table(:galleries) do
      modify(:use_global, :map, default: @default)
    end
  end
end
