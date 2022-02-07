defmodule Picsello.Notifiers.ClientNotifierTest do
  use Picsello.DataCase, async: true
  alias Picsello.{Notifiers.ClientNotifier, Job}

  test "adds reply-to header" do
    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)

    user =
      insert(:user, organization: params_for(:organization, %{name: "Photography 123"}))
      |> onboard!()

    job = insert(:lead, user: user)
    message = insert(:client_message, job: job) |> Repo.reload()

    assert {:ok, %{headers: %{"reply-to" => reply_to}}} =
             ClientNotifier.deliver_email(message, "test@example.com")

    token = Job.token(job)

    assert "Photography 123 <#{token}@test-inbox.picsello.com>" == reply_to
  end
end
