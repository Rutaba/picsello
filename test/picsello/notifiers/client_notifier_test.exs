defmodule Picsello.Notifiers.ClientNotifierTest do
  use Picsello.DataCase, async: true
  alias Picsello.{Notifiers.ClientNotifier, Job}

  test "adds reply-to header" do
    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)

    job = insert(:lead, client: %{organization: %{name: "Photography 123"}})
    message = insert(:client_message, job: job)

    assert {:ok, %{headers: %{"reply-to" => reply_to}}} =
             ClientNotifier.deliver_email(message, "test@example.com")

    token = Job.token(job)

    assert "Photography 123 <#{token}@test-inbox.picsello.com>" == reply_to
  end
end
