defmodule Picsello.Repo.Migrations.AddBuyAllConstraintToPackages do
  use Ecto.Migration

  def change do
    execute(
      """
        update packages
        set buy_all = null
        where buy_all is not null and (buy_all <= download_each_price or download_each_price = 0)
      """,
      ""
    )

    create(
      constraint(:packages, "download_each_price_positive", check: "download_each_price >= 0")
    )

    # download_each_price | buy_all | valid?
    # 0                   | null    | valid
    # 1                   | null    | valid
    # 0                   | 0       | invalid
    # 1                   | 0       | invalid
    # 0                   | 1       | invalid
    # 1                   | 1       | invalid
    # 1                   | 2       | valid

    create(
      constraint(:packages, "buy_all_greater_download_each_price",
        check: "buy_all is null or (buy_all > download_each_price and download_each_price > 0)"
      )
    )
  end
end
