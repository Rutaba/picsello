defmodule Picsello.Shoots do
  @moduledoc false

  alias Picsello.{Repo, Shoot, Job}
  import Ecto.Query

  def get_shoots(user, %{"start" => start_date, "end" => end_date}) do
    from(shoot in Shoot,
      join: job in assoc(shoot, :job),
      join: client in assoc(job, :client),
      join: status in assoc(job, :job_status),
      where:
        client.organization_id == ^user.organization.id and
          is_nil(job.archived_at) and is_nil(job.completed_at) and shoot.starts_at >= ^start_date and
          shoot.starts_at <= ^end_date and
          (status.is_lead == false or is_nil(job.booking_event_id)),
      select: {shoot, job, client, status},
      order_by: shoot.starts_at
    )
    |> Repo.all()
  end

  def get_next_shoot(%Job{shoots: shoots}) when is_nil(shoots), do: nil

  def get_next_shoot(%Job{shoots: shoots}) do
    shoots
    |> Enum.filter(&(&1.starts_at >= DateTime.utc_now()))
    |> Enum.sort_by(& &1.starts_at)
    |> List.first()
  end

  def get_latest_shoot(job_id) do
    Shoot
    |> where([s], s.job_id == ^job_id)
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def broadcast_shoot_change(%Shoot{} = shoot) do
    job = shoot |> Repo.preload(job: :client) |> Map.get(:job)

    Phoenix.PubSub.broadcast(
      Picsello.PubSub,
      topic_shoot_change(job.client.organization_id),
      {:shoot_updated, shoot}
    )
  end

  def subscribe_shoot_change(organization_id),
    do: Phoenix.PubSub.subscribe(Picsello.PubSub, topic_shoot_change(organization_id))

  defp topic_shoot_change(organization_id), do: "shoot_change:#{organization_id}"
end
