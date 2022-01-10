defmodule Picsello.Messages do
  @moduledoc """
  The Messages context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias Picsello.Job
  alias Picsello.Repo

  def add_message_to_job(%Changeset{} = changeset, %Job{} = job) do
    changeset
    |> Changeset.put_change(:job_id, job.id)
    |> Repo.insert()
  end
end
