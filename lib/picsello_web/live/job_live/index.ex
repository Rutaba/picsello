defmodule PicselloWeb.JobLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Job, Repo}
  require Ecto.Query
  alias Ecto.Query

  @impl true
  def mount(_params, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign_jobs()
    |> ok()
  end

  defp assign_jobs(%{assigns: %{current_user: current_user}} = socket) do
    socket
    |> assign(
      jobs:
        current_user
        |> Job.for_user()
        |> Query.preload(:client)
        |> Query.order_by(desc: :updated_at)
        |> Repo.all()
    )
  end
end