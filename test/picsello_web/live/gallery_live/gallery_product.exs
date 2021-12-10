defmodule PicselloWeb.GalleryLive.GalleryProductTest do
  @moduledoc false
  #use PicselloWeb.ConnCase, async: true

  use Picsello.FeatureCase, async: true

  alias Picsello.Repo
  alias Picsello.Galleries.Gallery
  alias Picsello.Galleries.GalleryProduct
  alias Picsello.Galleries.Photo
  alias Picsello.Category
  alias Picsello.CategoryTemplates
  require Logger

  setup :onboarded
  setup :authenticated

  # setup %{user: user, session: session} do
  #   %{booking_proposals: [proposal]} =
  #     job =
  #     insert(:lead, user: user)
  #     |> promote_to_job()
  #     |> Repo.preload(:booking_proposals)

  #   #proposal |> with_completed_questionnaire()

  #   session
  #   |> visit("/jobs/#{job.id}")

  #   [user: user]
  # end

  test "connected mount", %{session: session} do
    seed_category_teplate()
    #insert(:user)

    %{id: job_id} = insert(:lead)
    %{id: id} = insert(%Gallery{name: "testGalleryName", job_id: job_id})
    photo_url = "card_blank.png"
    %{id: _p_id} = insert(%Photo{gallery_id: id, preview_url: photo_url, original_url: photo_url, name: photo_url, position: 1})
    %{id: g_id} = insert(%GalleryProduct{gallery_id: id, category_template_id: 1})

    session |> visit("/galleries/#{id}") |> click(css(".prod-link0"))


    # session |> visit("/galleries/#{id}/product/#{g_id}") |> click(css(".item-content"))
    # session |> click(css(".save-button"))

    take_screenshot(session)
    print_page_source(session)
    # %{preview_photo: %{name: url}} = Repo.get_by(GalleryProduct, %{id: g_id}) |> Repo.preload([:preview_photo])

    # # IO.inspect r
    # assert photo_url == url
  end

  def print_page_text(session) do
    session |> Wallaby.Browser.text() |> IO.inspect()
    session
  end
  def print_page_source(session) do
    session |> Wallaby.Browser.page_source() |> IO.inspect()
    session
  end

  def seed_category_teplate() do
    frames = [
      %{name: "card_blank.png", corners: [0, 0, 0, 0, 0, 0, 0, 0]},
      %{name: "album_transparency.png", corners: [800, 715, 1720, 715, 800, 1620, 1720, 1620]},
      %{name: "card_envelop.png", corners: [1650, 610, 3100, 610, 1650, 2620, 3100, 2620]},
      %{name: "frame_transperancy.png", corners: [550, 550, 2110, 550, 550, 1600, 2110, 1600]}
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
  end
end
