defmodule Picsello.GalleryExpirationReminderTest do
  use Picsello.DataCase, async: true
  alias Picsello.{Galleries, ClientMessage, GalleryExpirationReminder, Repo}
  require Ecto.Query

  setup do
    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)
    :ok

    [now: DateTime.utc_now()]
  end

  def messages_by_job,
    do:
      from(r in ClientMessage, group_by: r.job_id, select: {r.job_id, count(r.id)})
      |> Repo.all()
      |> Enum.into(%{})

  describe "deliver_all" do
    test "delivers messages to expired galleries", %{now: now} do
      organization = insert(:organization, name: "Kloster Oberzell", slug: "kloster-oberzell")
      insert(:user, organization: organization, onboarding: %{phone: "(918) 555-1234"})

      %{id: job_id} =
        insert(:lead,
          type: "wedding",
          client: insert(:client, name: "Johann Zahn", organization: organization)
        )
        |> Picsello.Repo.reload!()

      expiration = now |> DateTime.add(3 * day()) |> DateTime.add(10)

      Galleries.Gallery.create_changeset(%Galleries.Gallery{}, %{
        job_id: job_id,
        name: "12345Gallery",
        status: "expired",
        expired_at: expiration
      })
      |> Repo.insert!()
      |> Galleries.set_gallery_hash()

      :ok =
        now
        |> DateTime.add(3 * day())
        |> DateTime.add(10)
        |> GalleryExpirationReminder.deliver_all()

      assert_receive {:delivered_email, email}

      assert %{"body_html" => body_html, "body_text" => body_text, "subject" => subject} =
               email |> email_substitutions()

      assert "Gallery Expiration Reminder" == subject
      assert String.starts_with?(body_html, "<p>Hello Johann Zahn,</p>")
      assert String.starts_with?(body_text, "Hello Johann Zahn,\n")
    end

    test "delivers no emails before the expiration date", %{now: _now} do
      assert false
    end

    test "delivers no email when status is expired but date is not expired", %{now: _now} do
      assert false
    end

    def day(), do: 24 * 60 * 60
  end
end
