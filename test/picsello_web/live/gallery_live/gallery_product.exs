defmodule PicselloWeb.GalleryLive.GalleryProductTest do
  @moduledoc false
  #use PicselloWeb.ConnCase, async: true

  use Picsello.FeatureCase, async: true

  alias Picsello.{Repo, BookingProposal}
  import Ecto.Query

  import Phoenix.LiveViewTest
  alias Picsello.Repo
  alias Picsello.Galleries.Gallery
  alias Picsello.Galleries.GalleryProduct
  alias Picsello.Galleries.Photo
  alias Picsello.Category
  alias Picsello.CategoryTemplates
  alias Picsello.Repo
  alias Picsello.Galleries
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
    us = insert(:user)

    %{id: job_id} = insert(:lead)
    %{id: id} = insert(%Gallery{name: "testGalleryName", job_id: job_id})
    photo_url = "images/card_blank.png"
    %{id: p_id} = insert(%Photo{gallery_id: id, preview_url: photo_url, original_url: photo_url, name: photo_url, position: 1})
    r = insert(%GalleryProduct{gallery_id: id, category_template_id: 1})
    IO.inspect [r]

    #%{id: id} = Gallery.create_changeset(%Gallery{}, %{job_id: job_id, name: "12345Gallery"})
    #|> Repo.insert!()

    session |> visit("/galleries/#{id}")# |> find(css("#canvas0"))
      |> click(Query.css("#canvas0"))
      Process.sleep(5000)
      take_screenshot(session)
    #r = Picsello.Repo.all(from u in "galleries", select: u.name)
    #{:ok, _view, html} = live(conn, "/galleries/#{id}")
    #IO.inspect r
    #assert html =~ "12345"
  end

  # describe "render" do
  #   setup %{conn: conn} do
  #     conn = conn |> log_in_user(insert(:user) |> onboard!)
  #     %{conn: conn, gallery: insert(:gallery, %{name: "Diego Santos Weeding"})}
  #   end
  #     # test "connected mount", %{conn: conn, gallery: gallery} do
  #     #   {:ok, _view, html} = live(conn, "/galleries/#{gallery.id}/settings")
  #     #   assert html |> Floki.text() =~ "Gallery Settings"
  #     #   assert html |> Floki.text() =~ "Gallery name"
  #     #   assert html |> Floki.text() =~ "Gallery password"
  #     #   assert html |> Floki.text() =~ "Custom watermark"
  #     # end

  #   test "disconnected and connected mount", %{conn: conn} do
  #     conn = get(conn, "/home")
  #     assert html_response(conn, 200) =~ "Good Afternoon"

  #     {:ok, _view, _html} = live(conn)
  #   end

  # end


  def seed_category_teplate() do
    frames = [
      %{name: "card_blank.png", corners: [0, 0, 0, 0, 0, 0, 0, 0]},
      %{name: "album_transparency.png", corners: [800, 715, 1720, 715, 800, 1620, 1720, 1620]},
      %{name: "card_envelope.png", corners: [0, 0, 0, 0, 0, 0, 0, 0]},
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
