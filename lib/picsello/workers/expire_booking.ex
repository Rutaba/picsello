defmodule Picsello.Workers.ExpireBooking do
  @moduledoc "Background job to expire a lead created from a booking event"

  use Oban.Worker, unique: [fields: [:args, :worker]]
  alias Picsello.{Repo, Job, BookingEvents}

  def perform(%Oban.Job{args: %{"id" => job_id}}) do
    Job
    |> Repo.get(job_id)
    |> BookingEvents.expire_booking()
  end
end
