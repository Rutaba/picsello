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
    now
    |> DateTime.add(7 * day())
    |> DateTime.truncate(:second)
    |> Galleries.list_soon_to_be_expired_galleries()
    |> Enum.each(&maybe_send_message(&1))
  end

  defp maybe_send_message(%Picsello.Galleries.Gallery{
         job_id: job_id,
         password: password,
         expired_at: expired_at,
         client_link_hash: client_link_hash
       }) do
    has_gallery_expiration_messages? =
      from(r in ClientMessage,
        where: r.subject == "Gallery Expiration Reminder" and r.job_id == ^job_id
      )
      |> Repo.all()

    copy = """
    Hello <%= client_name %>,

    Your gallery is about to expire! Please log into your gallery and make your selections before the gallery expires on <%= expired_at %>

    A reminder your photos are password-protected, so you will need to use this password to view: <%= password %>

    You can log into your private gallery to see all of your images: #{PicselloWeb.Endpoint.url()}/gallery/#{client_link_hash}.

    It’s been a delight working with you and I can’t wait to hear what you think!
    """

    unless has_gallery_expiration_messages? != [] do
      {client_id, client_name, client_email, organization_name} =
        Repo.one(
          from(job in Job,
            join: client in Client,
            on: client.id == job.client_id,
            join: organization in Organization,
            on: organization.id == client.organization_id,
            where: job.id == ^job_id and is_nil(job.archived_at),
            select: {client.id, client.name, client.email, organization.name}
          )
        )

      body =
        EEx.eval_string(copy,
          organization_name: organization_name,
          client_name: client_name,
          password: password,
          expired_at: Calendar.strftime(expired_at, "%m/%d/%y"),
          client_link_hash: client_link_hash
        )

      %{subject: "Gallery Expiration Reminder", body_text: body, body_html: body_html(body)}
      |> ClientMessage.create_outbound_changeset()
      |> Ecto.Changeset.put_change(:job_id, job_id)
      |> Ecto.Changeset.put_change(:client_message_recipients, [
        %{client_id: client_id, recipient_type: "to"}
      ])
      |> Ecto.Changeset.put_change(:scheduled, true)
      |> Repo.insert!()
      |> ClientNotifier.deliver_email(client_email)
    end
  end

  defp day(), do: 24 * 60 * 60

  defp body_html(body),
    do: body |> Phoenix.HTML.Format.text_to_html() |> Phoenix.HTML.safe_to_string()
end
