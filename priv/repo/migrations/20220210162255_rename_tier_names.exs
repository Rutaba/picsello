defmodule Picsello.Repo.Migrations.RenameTierNames do
  use Ecto.Migration

  def change do
    execute("ALTER TABLE package_base_prices DROP CONSTRAINT package_base_prices_tier_fkey")

    execute("update package_base_prices set tier = 'essential' where tier = 'bronze'")
    execute("update package_base_prices set tier = 'keepsake' where tier = 'silver'")
    execute("update package_base_prices set tier = 'heirloom' where tier = 'gold'")

    values =
      for(
        {name, position} <- ~w(essential keepsake heirloom) |> Enum.with_index(),
        do: "('#{name}',#{position})"
      )
      |> Enum.join(",")

    execute("delete from package_tiers")

    execute("""
    insert into package_tiers(name, position)
    values #{values}
    """)

    alter table(:package_base_prices) do
      modify(:tier, references(:package_tiers, column: :name, type: :string))
    end
  end
end
