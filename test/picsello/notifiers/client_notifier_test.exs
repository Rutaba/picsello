defmodule Picsello.Notifiers.ClientNotifierTest do
  use Picsello.DataCase, async: true
  alias Picsello.{Notifiers.ClientNotifier, Messages}

  test "adds reply-to header" do
    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)

    user =
      insert(:user, organization: params_for(:organization, %{name: "Photography 123"}))
      |> onboard!()

    job = insert(:lead, user: user)

    message =
      insert(:client_message,
        job: job,
        client_message_recipients: [%{client_id: job.client_id, recipient_type: :to}]
      )
      |> Repo.reload()

    assert {:ok, %{headers: %{"reply-to" => reply_to}}} =
             ClientNotifier.deliver_email(message, %{"to" => "test@example.com"})

    token = Messages.token(job)

    assert "Photography 123 <#{token}@test-inbox.picsello.com>" == reply_to
  end

  test "adds reply-to header for client" do
    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)

    user =
      insert(:user, organization: params_for(:organization, %{name: "Photography 123"}))
      |> onboard!()

    client = insert(:client, user: user)

    message =
      insert(:client_message,
        client_message_recipients: [%{client_id: client.id, recipient_type: :to}]
      )
      |> Repo.reload()

    assert {:ok, %{headers: %{}}} =
             ClientNotifier.deliver_email(message, %{"to" => "test@example.com"})
  end
end
