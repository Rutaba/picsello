defmodule Picsello.GalleryShareTest do
  use Picsello.FeatureCase, async: true
  use Oban.Testing, repo: Picsello.Repo

  alias Picsello.Galleries.PhotoProcessing.Waiter

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup %{gallery: gallery} do
    Mox.stub(Picsello.PhotoStorageMock, :path_to_url, & &1)
    photo_ids = insert_photo(%{gallery: gallery, total_photos: 20})

    Mox.verify_on_exit!()

    Picsello.Sandbox.allow(
      Picsello.Repo,
      self(),
      Process.whereis(Picsello.Galleries.PhotoProcessing.Waiter)
    )

    insert(:email_preset, type: :gallery, state: :gallery_send_link)

    [photo_ids: photo_ids]
  end

  feature "test `share gallery` gets delayed till processing completed", %{
    session: session,
    gallery: gallery
  } do
    Waiter.start_tracking(gallery.id, 1)

    test_pid = self()

    :ok =
      :telemetry.attach(
        "oban-job-finish",
        [:oban, :engine, :cancel_job, :stop],
        fn _event, _stats, job, _args ->
          send(test_pid, {:job_canceled, job})
        end,
        []
      )

    session
    |> visit("/galleries/#{gallery.id}")
    |> click(button("Share gallery"))
    |> within_modal(fn modal ->
      modal
      |> wait_for_enabled_submit_button(text: "Send Email")
      |> click(button("Send Email"))
    end)

    assert_enqueued([worker: Picsello.Workers.ScheduleEmail], 100)
    refute_receive {:delivered_email, _}
    Waiter.complete_tracking(gallery.id, 1)
    assert_receive {:job_canceled, _}, 500
    assert_receive {:delivered_email, _}
  end
end
