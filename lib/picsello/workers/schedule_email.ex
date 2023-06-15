defmodule Picsello.Workers.ScheduleEmail do
  @moduledoc "Background job to send scheduled emails"
  use Oban.Worker, queue: :default

  alias Picsello.{Job, Messages, Repo, Notifiers.ClientNotifier}

  def perform(%Oban.Job{
        args: %{
          "message" => message_serialized,
          "recipients" => recipients,
          "job_id" => job_id,
          "user" => user
        }
      }) do
    message_changeset =
      message_serialized
      |> Base.decode64!()
      |> :erlang.binary_to_term()

    job = Job.by_id(job_id) |> Repo.one!()

    {:ok, %{client_message: message, client_message_recipients: _}} =
      Messages.add_message_to_job(message_changeset, job, recipients, user) |> Repo.transaction()

    ClientNotifier.deliver_email(message, recipients)
    :ok
  end
end
