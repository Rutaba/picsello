defmodule Picsello.GalleryShareTest do
  use Picsello.FeatureCase, async: false
  use Oban.Testing, repo: Picsello.Repo

  alias Picsello.Galleries.PhotoProcessing.Waiter

  setup :authenticated
  setup :onboarded
  setup :authenticated_gallery

  setup(context) do
    Ecto.Adapters.SQL.Sandbox.mode(Picsello.Repo, {:shared, self()})

    context
    |> Mox.set_mox_from_context()
  end

  feature "test `share gallery` gets delayed till processing completed", %{
    session: session,
    gallery: gallery
  } do
    Waiter.start_tracking(gallery.id, 1)

    session
    |> visit("/galleries/#{gallery.id}/")
    |> assert_has(css("button", count: 1, text: "Share gallery"))
    |> click(css("button", text: "Share gallery"))
    |> assert_has(css("button", text: "Send Email"))
    |> click(css("button", text: "Send Email"))

    assert_enqueued(worker: Picsello.Workers.ScheduleEmail)
    refute_receive {:delivered_email, _}
    Process.sleep(100)

    Mox.expect(Picsello.MockBambooAdapter, :deliver, fn email, _ -> {:ok, email} end)

    Waiter.complete_tracking(gallery.id, 1)
    Process.sleep(100)
    assert [] = all_enqueued()
  end
end
