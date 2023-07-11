defmodule Picsello.Workers.ScheduleEmail do
  @moduledoc "Background job to send scheduled emails"
  use Oban.Worker, queue: :default

  import PicselloWeb.Live.Shared, only: [deserialize: 1]
  alias Picsello.{Job, Messages, Repo, Notifiers.ClientNotifier}

  def perform(%Oban.Job{
        args: %{
          "message" => message_serialized,
          "recipients" => recipients,
          "job_id" => job_id,
          "user" => user_serialized
        }
      }) do
    message_changeset = deserialize(message_serialized)
    user = deserialize(user_serialized)
    job = Job.by_id(job_id) |> Repo.one!()

    {:ok, %{client_message: message, client_message_recipients: _}} =
      Messages.add_message_to_job(message_changeset, job, recipients, user) |> Repo.transaction()

    ClientNotifier.deliver_email(message, recipients)
    :ok
  end
end
