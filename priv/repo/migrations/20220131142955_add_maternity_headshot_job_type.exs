defmodule Picsello.Repo.Migrations.AddMaternityHeadshotJobType do
  use Ecto.Migration

  def change do
    execute(
      """
      insert into job_types (name, position) values
      ('wedding', 0),
      ('family', 1),
      ('maternity', 2),
      ('newborn', 3),
      ('event', 4),
      ('headshot', 5),
      ('portrait', 6),
      ('mini', 7),
      ('boudoir', 8),
      ('other', 9)
      on conflict (name) do update set position = excluded.position
      """,
      "delete from job_types where name in ('maternity', 'headshot')"
    )
  end
end
