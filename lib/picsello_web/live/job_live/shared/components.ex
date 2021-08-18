defmodule PicselloWeb.JobLive.Shared.Components do
  @moduledoc "markup used for jobs and leads"
  defmodule Header do
    @moduledoc false
    use PicselloWeb, :live_component
    alias Picsello.Job

    def render(assigns) do
      ~L"""
        <div class="text-xs text-gray-400">
          <%= live_redirect to: Routes.job_path(@socket, @live_action) do %>
            <%= action_name(@live_action, :plural) %>
          <% end %>
          &gt;
          <%= Job.name @job %>
        </div>

        <h1 class="text-2xl font-bold mt-7"><%= Job.name @job %></h1>
      """
    end
  end

  defmodule Details do
    @moduledoc false
    use PicselloWeb, :live_component
    alias Picsello.Job

    def render(assigns) do
      ~L"""
        <h2 class="mt-5 text-xs font-bold uppercase"><%= action_name(@live_action) %> Details</h2>
        <button title="Edit <%= action_name(@live_action) %>" type="button" phx-click="edit-job" class="mt-2 btn-row">
          <%= Job.name @job %>
          <%= icon_tag(@socket, "forth", class: "stroke-current h-6 w-6") %>
        </button>
      """
    end
  end

  defmodule ShootDetails do
    @moduledoc false
    use PicselloWeb, :live_component

    def render(assigns) do
      ~L"""

        <%= for {shoot_number, shoot} <- @shoots do %>
          <%= if shoot do %>
            <button title="Edit shoot" type="button" phx-click="edit-shoot-details" phx-value-shoot-number="<%= shoot_number %>" phx-value-shoot-id="<%= shoot.id %>" class="mb-3 btn-row">
              <%= shoot.name %>
              <%= icon_tag(@socket, "forth", class: "stroke-current h-6 w-6") %>
            </button>
          <% else %>
            <div class="flex flex-col items-center p-6 mb-3 bg-gray-100 rounded-2xl">
              <div>Shoot <%= shoot_number %></div>
              <a href="#" phx-click="edit-shoot-details" phx-value-shoot-number="<%= shoot_number %>" class="link">Add shoot details</a>
            </div>
          <% end %>
        <% end %>
      """
    end
  end

  defmodule BookingDetails do
    @moduledoc false
    use PicselloWeb, :live_component

    def render(assigns) do
      ~L"""
        <p class="mt-4 text-sm font-bold">
          The following details were included in the booking proposal sent on <%= Calendar.strftime(@proposal.inserted_at, "%m/%d/%y") %>
        </p>
        <ul class="pt-4 ml-8 list-disc">
          <li>Proposal</li>
          <li>Contract (standard)</li>
          <%= if @proposal.questionnaire_id do %>
            <li>Questionaire</li>
          <% end %>
        </ul>
        <button class="w-full mt-6 btn-primary" phx-click="open-proposal">View booking proposal</button>
      """
    end
  end
end
