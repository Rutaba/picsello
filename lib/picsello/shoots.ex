defmodule Picsello.Shoots do
  @moduledoc false

  alias Picsello.{Repo, Shoot}
  import Ecto.Query

  def get_shoots(user, %{"start" => start_date, "end" => end_date}) do
    from(shoot in Shoot,
      join: job in assoc(shoot, :job),
      join: client in assoc(job, :client),
      join: status in assoc(job, :job_status),
      where:
        client.organization_id == ^user.organization.id and
          is_nil(job.archived_at) and shoot.starts_at >= ^start_date and
          shoot.starts_at <= ^end_date,
      select: {shoot, job, client, status}
    )
    |> Repo.all()
  end
end
