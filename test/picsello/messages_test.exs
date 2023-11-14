defmodule Picsello.MessagesTest do
  use Picsello.DataCase, async: true

  alias Picsello.{Messages, ClientMessage}

  setup do
    user = insert(:user)
    client = insert(:client, user: user)
    job = insert(:lead, user: user, client: client, type: "wedding") |> promote_to_job()

    client_message =
      insert(:client_message,
        outbound: false,
        read_at: nil
      )

    job_message =
      insert(:client_message,
        job: job,
        read_at: nil
      )

    insert(:client_message_recipient, client_message: client_message, client_id: job.client_id)
    insert(:client_message_recipient, client_message: job_message, client_id: job.client_id)

    [job: job, user: user, client_msg: client_message, job_msg: job_message]
  end

  test "add_message_to_job/4", %{job: job, user: user} do
    recipients_list = %{"to" => [job.client.email]}

    assert MapSet.new([:client_message, :client_message_recipients]) ==
             %{
               body_html: "Test</p>",
               body_text: "test",
               subject: "Test"
             }
             |> ClientMessage.create_outbound_changeset()
             |> Messages.add_message_to_job(job, recipients_list, user)
             |> Map.get(:names)
  end

  test "add_message_to_client/3", %{job: job, user: user} do
    recipients_list = %{"to" => [job.client.email]}

    assert MapSet.new([:client_message, :client_message_recipients]) ==
             %{
               body_html: "Test</p>",
               body_text: "test",
               subject: "Test"
             }
             |> ClientMessage.create_outbound_changeset()
             |> Messages.add_message_to_client(recipients_list, user)
             |> Map.get(:names)
  end

  test "insert_scheduled_message!/2", %{job: job} do
    assert "test" ==
             %{
               body_html: "Test</p>",
               body_text: "test",
               subject: "Test"
             }
             |> Messages.insert_scheduled_message!(job)
             |> Map.get(:body_text)
  end

  test "scheduled_message_changeset/2", %{job: job} do
    assert true ==
             %{
               body_html: "Test</p>",
               body_text: "test",
               subject: "Test"
             }
             |> Messages.scheduled_message_changeset(job)
             |> Map.get(:valid?)
  end

  test "notify_inbound_message/2 without job_id", %{client_msg: message} do
    assert nil == Messages.notify_inbound_message(message, PicselloWeb.Helpers)
  end

  test "notify_inbound_message/2 with job_id", %{job_msg: message} do
    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)

    {:ok, bambo_email} = Messages.notify_inbound_message(message, PicselloWeb.Helpers)

    assert {nil, "photographer-notifications@picsello.com"} == bambo_email.from
  end

  test "find_by_token/1", %{job: job} do
    token = Messages.token(job)
    assert job.id == Messages.find_by_token(token).id
  end

  test "job_threads/1", %{user: user} do
    assert 1 == Messages.job_threads(user) |> length()
  end

  test "client_threads/1", %{user: user} do
    assert 1 == Messages.client_threads(user) |> length()
  end

  test "for_job/1", %{job: job} do
    assert 1 == job |> Messages.for_job() |> length()
  end

  test "unread_messages/1", %{job: job, user: user} do
    {[job_id], [client_id], _campaign_ids, _message_ids} = user |> Messages.unread_messages()

    assert job.id == job_id
    assert client_id = job.client_id
  end

  test "update_all/3 for client messages with read_at, delete_at coloum ", %{job: job} do
    assert {1, nil} == Messages.update_all(job.client_id, :client, :read_at)

    assert {1, nil} == Messages.update_all(job.client_id, :client, :deleted_at)
  end

  test "update_all/3 for job messages with read_at, delete_at coloum ", %{job: job} do
    assert {1, nil} == Messages.update_all(job.id, :job, :read_at)

    assert {1, nil} == Messages.update_all(job.id, :job, :deleted_at)
  end
end
