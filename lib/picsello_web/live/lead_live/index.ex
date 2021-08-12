defmodule PicselloWeb.LeadLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{Job, Repo}
  require Ecto.Query
  alias Ecto.Query

  @impl true
  def mount(_params, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign_leads()
    |> ok()
  end

  defp assign_leads(%{assigns: %{current_user: current_user}} = socket) do
    socket
    |> assign(
      leads:
        current_user
        |> Job.for_user()
        |> Job.leads()
        |> Query.preload(:client)
        |> Query.order_by(desc: :updated_at)
        |> Repo.all()
    )
  end
end
