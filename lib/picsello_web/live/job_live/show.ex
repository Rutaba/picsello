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

  def overview_card(assigns) do
    ~H"""
      <li class="flex flex-col justify-between p-4 border rounded-lg">
        <div>
          <div class="mb-6 font-bold">
            <%= icon_tag(@socket, @icon, class: "stroke-current h-6 w-5 inline mr-2") %>
            <%= @title %>
          </div>

          <%= render_block(@inner_block) %>
        </div>

        <button type="button" class="w-full p-2 mt-6 text-sm text-center border border-black rounded-lg" >
          <%= @button_text %>
        </button>
      </li>
    """
  end

  @impl true
  defdelegate handle_event(name, params, socket), to: PicselloWeb.JobLive.Shared

  @impl true
  defdelegate handle_info(message, socket), to: PicselloWeb.JobLive.Shared
  defdelegate assign_job(socket, job_id), to: PicselloWeb.JobLive.Shared
  defdelegate assign_proposal(socket), to: PicselloWeb.JobLive.Shared
end
