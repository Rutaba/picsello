defmodule Picsello.GalleryExpirationReminderTest do
  use Picsello.DataCase, async: true
  alias Picsello.{Galleries, ClientMessage, GalleryExpirationReminder, Repo}
  require Ecto.Query

  setup do
    now = DateTime.utc_now()

    user =
      insert(:user,
        email: "photographer@example.com",
        organization: params_for(:organization, name: "Photography LLC")
      )
      |> onboard!

    %{id: job_id} =
      insert(
        :lead,
        %{
          user: user,
          type: "wedding",
          client: %{name: "Johann Zahn"}
        }
      )

    Galleries.Gallery.create_changeset(%Galleries.Gallery{}, %{
      job_id: job_id,
      name: "12345Gallery",
      status: "active"
    })
    |> Galleries.Gallery.expire_changeset(%{expired_at: now |> DateTime.add(7 * day())})
    |> Repo.insert!()
    |> Galleries.set_gallery_hash()

    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)
    :ok

    [now: now, job_id: job_id]
  end

  def messages_by_job,
    do:
      from(r in ClientMessage, group_by: r.job_id, select: {r.job_id, count(r.id)})
      |> Repo.all()
      |> Enum.into(%{})

  def messages_by_expiration_subject(job_id),
    do:
      from(r in ClientMessage,
        where: r.subject == "Gallery Expiration Reminder" and r.job_id == ^job_id
      )
      |> Repo.all()
      |> Enum.count()

  describe "deliver_all" do
    test "delivers messages to expired galleries", %{now: now} do
      :ok =
        now
        |> GalleryExpirationReminder.deliver_all()

      assert_receive {:delivered_email, email}

      assert %{"body_html" => body_html, "body_text" => body_text, "subject" => subject} =
               email |> email_substitutions()

      assert "Gallery Expiration Reminder" == subject
      assert String.starts_with?(body_html, "<p>Hello Johann Zahn,</p>")
      assert String.starts_with?(body_text, "Hello Johann Zahn,\n")
    end

    test "delivers no emails before the expiration date", %{now: now} do
      :ok =
        now
        |> DateTime.add(-10)
        |> GalleryExpirationReminder.deliver_all()

      assert %{} == messages_by_job()
    end

    test "delivers no emails when an expiration reminder has already been sent", %{
      now: now,
      job_id: job_id
    } do
      GalleryExpirationReminder.deliver_all(now)
      GalleryExpirationReminder.deliver_all(now)

      :ok =
        now
        |> GalleryExpirationReminder.deliver_all()

      assert messages_by_expiration_subject(job_id) == 1
    end

    def day(), do: 24 * 60 * 60
  end
end
