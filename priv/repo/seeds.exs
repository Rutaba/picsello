# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Picsello.Repo.insert!(%Picsello.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

require Logger
alias Picsello.CategoryTemplates
alias Picsello.Repo
alias Picsello.Category

frames = [
  %{name: "card_blank.png", corners: [0, 0, 0, 0, 0, 0, 0, 0]},
  %{name: "album_transparency.png", corners: [800, 715, 1720, 715, 800, 1620, 1720, 1620]},
  %{name: "card_envelop.png", corners: [1650, 610, 3100, 610, 1650, 2620, 3100, 2620]},
  %{name: "frame_transparency.png", corners: [550, 550, 2110, 550, 550, 1600, 2110, 1600]}
]

unless Repo.aggregate(Category, :count) == 4 do
  Enum.each(frames, fn row ->
    length = Repo.aggregate(Category, :count)

    result =
      Repo.insert(%Category{
        name: "example_category",
        icon: "example_icon",
        position: length,
        whcc_id: Integer.to_string(length),
        whcc_name: "example_name"
      })

    case result do
      {:ok, %{id: category_id}} ->
        Repo.insert!(%CategoryTemplates{
          name: row.name,
          corners: row.corners,
          category_id: category_id
        })

      x ->
        Logger.error("category_template seed was not inserted. #{x}")
    end
  end)
end
