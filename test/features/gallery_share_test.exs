defmodule Picsello.GalleryShareTest do
  use Picsello.FeatureCase, async: true
  use Oban.Testing, repo: Picsello.Repo

  alias Picsello.Galleries.PhotoProcessing.Waiter

  setup :authenticated
  setup :onboarded

  setup %{user: user} do
    Mox.verify_on_exit!()

    Picsello.Sandbox.allow(
      Picsello.Repo,
      self(),
      Process.whereis(Picsello.Galleries.PhotoProcessing.Waiter)
    )

    [gallery: insert(:gallery, job: insert(:lead, user: user))]
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
    |> visit("/galleries/#{gallery.id}/")
    |> assert_has(css("button", count: 1, text: "Share gallery"))
    |> click(css("button", text: "Share gallery"))
    |> assert_has(css("button", text: "Send Email"))
    |> click(css("button", text: "Send Email"))

    assert_enqueued(worker: Picsello.Workers.ScheduleEmail)
    refute_receive {:delivered_email, _}
    Waiter.complete_tracking(gallery.id, 1)
    assert_receive {:job_canceled, _}, 500
    assert_receive {:delivered_email, _}
  end
end
