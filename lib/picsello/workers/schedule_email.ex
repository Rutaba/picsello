defmodule Picsello.Workers.ScheduleEmail do
  @moduledoc "Background job to send scheduled emails"
  use Oban.Worker, queue: :default

  alias Picsello.Job
  alias Picsello.Messages
  alias Picsello.Notifiers.ClientNotifier
  alias Picsello.Repo

  def perform(%Oban.Job{
        args: %{"message" => message_serialized, "recipients" => recipients, "job_id" => job_id}
      }) do
    message_changeset =
      message_serialized
      |> Base.decode64!()
      |> :erlang.binary_to_term()

    job = Job.by_id(job_id) |> Repo.one!()

    {:ok, message} = Messages.add_message_to_job(message_changeset, job, recipients)
    ClientNotifier.deliver_email(message, recipients)
    :ok
  end
end
