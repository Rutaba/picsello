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
  %{name: "card_blank.png", corners: [0, 0, 0, 0]},
  %{name: "album_transparency.png", corners: [800, 715, 1720, 1620]},
  %{name: "card_envelope.png", corners: [0, 0, 0, 0]},
  %{name: "frame_transperancy.png", corners: [550, 550, 2110, 1600]}
]

length = Repo.aggregate(Category, :count)

result =
  Repo.insert(%Category{
    name: "example_category",
    icon: "example_icon",
    position: length,
    whcc_id: Integer.to_string(:rand.uniform(9_999_999)),
    whcc_name: "example_name"
  })

case result do
  {:ok, %{id: category_id}} ->
    Enum.each(frames, fn row ->
      Repo.insert!(%CategoryTemplates{
        name: row.name,
        corners: row.corners,
        category_id: category_id
      })
    end)

  x ->
    Logger.error("category_template seed was not inserted. #{x}")
end
