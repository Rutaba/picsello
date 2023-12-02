defmodule Picsello.Repo.Migrations.BlackFridaySettings do
  use Ecto.Migration

  def change do
    [
      {5, "Black Friday Code", "Coupon code for Black Friday", "black_friday_code",
       "BLACKFRIDAY2024"},
      {6, "Black Friday Timer End Unix", "Black Friday Timer Ends", "black_friday_timer_end",
       "1704095999"}
    ]
    |> Enum.each(fn {id, title, description, slug, value} ->
      execute("""
        INSERT INTO admin_global_settings VALUES (#{id}, '#{title}', '#{description}', '#{slug}', '#{value}', 'active', now(), now());
      """)
    end)
  end
end
