defmodule Picsello.ProposalReminderTest do
  use Picsello.DataCase, async: true
  alias Picsello.{ProposalMessage, ProposalReminder, Repo}
  require Ecto.Query

  setup do
    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)
    :ok

    [now: DateTime.utc_now()]
  end

  def messages_by_proposal,
    do:
      from(r in ProposalMessage, group_by: r.proposal_id, select: {r.proposal_id, count(r.id)})
      |> Repo.all()
      |> Enum.into(%{})

  describe "deliver_all" do
    test "delivers messages to only unpaid unarchived proposals", %{now: now} do
      %{id: unpaid_id} = insert(:proposal)
      _unpaid_archived = insert(:proposal, job: insert(:lead, archived_at: now))
      _paid = insert(:proposal, deposit_paid_at: now)

      :ok = now |> DateTime.add(3 * day()) |> DateTime.add(10) |> ProposalReminder.deliver_all()

      assert %{unpaid_id => 1} == messages_by_proposal()

      assert_receive {:delivered_email, email}

      assert %{"body_html" => body_html, "body_text" => body_text, "subject" => subject} =
               email |> email_substitutions()

      assert "Proposal reminder" == subject
      assert String.starts_with?(body_html, "<p>Hi Mary Jane,</p>")
      assert String.starts_with?(body_text, "Hi Mary Jane,\n")
    end

    test "delivers no emails before the message delay", %{now: now} do
      _unpaid_id = insert(:proposal)

      :ok = now |> DateTime.add(3 * day()) |> DateTime.add(-10) |> ProposalReminder.deliver_all()

      assert %{} == messages_by_proposal()
    end

    test "delivers correct email in reminder schedule for elapsed days", %{now: now} do
      %{id: unpaid_id} = insert(:proposal)
      insert_list(2, :proposal_message, proposal_id: unpaid_id, scheduled: true)

      :ok = now |> DateTime.add(2 * day()) |> DateTime.add(10) |> ProposalReminder.deliver_all()

      %{^unpaid_id => 3} = messages_by_proposal()

      body =
        from(message in ProposalMessage,
          order_by: [desc: message.id],
          limit: 1,
          select: message.body_text
        )
        |> Repo.one()

      assert String.contains?(body, "last time")
    end

    def day(), do: 24 * 60 * 60
  end
end
