defmodule Picsello.Repo.Migrations.AddMorePhotographyTypes do
  use Ecto.Migration

  def up do
    alter(table(:job_types)) do
      add(:position, :integer, null: true)
    end

    unique_index(:job_types, :integer)

    values =
      for(
        {name, position} <- ~w(wedding family newborn event portrait other) |> Enum.with_index(),
        do: "('#{name}',#{position})"
      )
      |> Enum.join(",")

    execute("""
    insert into job_types(name, position)
    values #{values}
    on conflict (name) do update set name = job_types.name, position = excluded.position
    """)

    execute("delete from job_types where position is null")

    alter(table(:job_types)) do
      modify(:position, :integer, null: false)
    end
  end

  def down do
    alter(table(:job_types)) do
      remove(:position)
    end
  end
end
