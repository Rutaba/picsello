defmodule PicselloWeb.JobLive.Show do
  @moduledoc false
  use PicselloWeb, :live_view
  alias Picsello.Job

  @impl true
  def mount(%{"id" => job_id}, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign_job(job_id)
    |> assign_proposal()
    |> ok()
  end

  @impl true
  defdelegate handle_event(name, params, socket), to: PicselloWeb.JobLive.Shared

  @impl true
  defdelegate handle_info(message, socket), to: PicselloWeb.JobLive.Shared
  defdelegate assign_job(socket, job_id), to: PicselloWeb.JobLive.Shared
  defdelegate assign_proposal(socket), to: PicselloWeb.JobLive.Shared
end
