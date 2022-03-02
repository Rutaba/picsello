defmodule Picsello.Repo.Migrations.RenameTierNames do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE package_base_prices DROP CONSTRAINT package_base_prices_tier_fkey")
    tiers = [bronse: "essential", silver: "keepsake", gold: "heirloom"]

    for({old_name, new_name} <- tiers) do
      execute("update package_base_prices set tier = '#{new_name}' where tier = '#{old_name}'")
    end

    execute(
      "delete from package_base_prices where tier not in (#{tiers |> Keyword.values() |> Enum.map(&"'#{&1}'") |> Enum.join(",")})"
    )

    values =
      for(
        {name, position} <- Keyword.values(tiers) |> Enum.with_index(),
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

  def down, do: nil
end
