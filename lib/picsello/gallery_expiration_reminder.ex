defmodule Picsello.GalleryExpirationReminder do
  @moduledoc false

  alias Picsello.{
    Galleries,
    Job,
    Notifiers.ClientNotifier,
    ClientMessage,
    Organization,
    Client,
    Repo
  }

  import Ecto.Query, only: [from: 2]

  def deliver_all(now \\ DateTime.utc_now()) do
    Galleries.list_expired_galleries()
    |> Enum.each(&maybe_send_message(now, &1))
  end

  defp maybe_send_message(_, %Picsello.Galleries.Gallery{job_id: job_id}) do
    copy = """
    Hi <%= client_name %>,

    I hope your week is going well so far. I know life gets busy, but I wanted to reach out and touch base to see if there are any questions I can answer for you regarding the booking proposal! If you have any questions, just let me know, and I would be happy to answer them.

    Thank you,

    <%= organization_name %>
    """

    {client_name, client_email, organization_name} =
      Repo.one(
        from(job in Job,
          join: client in Client,
          on: client.id == job.client_id,
          join: organization in Organization,
          on: organization.id == client.organization_id,
          where: job.id == ^job_id and is_nil(job.archived_at),
          select: {client.name, client.email, organization.name}
        )
      )

    body = EEx.eval_string(copy, organization_name: organization_name, client_name: client_name)

    %{subject: "Gallery Expiration Reminder", body_text: body}
    |> ClientMessage.create_outbound_changeset()
    |> Ecto.Changeset.put_change(:job_id, job_id)
    |> Ecto.Changeset.put_change(:scheduled, true)
    |> IO.inspect()
    |> Repo.insert!()
    |> ClientNotifier.deliver_email(client_email)
  end
end
