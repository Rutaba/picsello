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

alias Picsello.Galleries.Category
alias Picsello.Repo
alias Picsello.Category

frames = [
  "card_blank.png",
  "album_transparency.png",
  "card_envelope.png",
  "frame_transperancy.png"
]

Picsello.Repo.insert!(%Category{
  name: "test_cat",
  icon: "test.png",
  position: 1,
  whcc_id: "1",
  whcc_name: "whcc_test"
})

Enum.each(frames, fn f_name ->
  Repo.insert!(%CategoryTemplate{frame_url: f_name})
end)
