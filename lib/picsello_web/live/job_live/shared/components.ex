defmodule PicselloWeb.JobLive.Shared.Components do
  @moduledoc "markup used for jobs and leads"

  defmodule Details do
    @moduledoc false
    use PicselloWeb, :live_component
    alias Picsello.Job

    def render(assigns) do
      ~L"""
        <h2 class="mt-6 text-xs font-semibold tracking-widest text-gray-400 uppercase"><%= action_name(@live_action) %> Details</h2>
        <button
          title="Edit <%= action_name(@live_action) %>"
          type="button"
          phx-click="edit-job"
          class="mt-2 btn-row">
          <%= Job.name @job %>
          <%= icon_tag(@socket, "forth", class: "stroke-current h-4 w-4") %>
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
            <button
              class="mt-3 btn-row"
              phx-click="edit-shoot-details"
              phx-value-shoot-id="<%= shoot.id %>"
              phx-value-shoot-number="<%= shoot_number %>"
              title="Edit shoot"
              type="button"
            >
              <%= shoot.name %>
              <%= icon_tag(@socket, "forth", class: "stroke-current h-4 w-4") %>
            </button>
          <% else %>
            <button
              class="mt-3 btn-row"
              phx-click="edit-shoot-details"
              phx-value-shoot-number="<%= shoot_number %>"
              title="Add shoot details"
              type="button"
            >
              Shoot <%= shoot_number %> (add details)
              <%= icon_tag(@socket, "forth", class: "stroke-current h-4 w-4") %>
            </button>
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
          The following details were included in the booking proposal sent on <%= strftime(@current_user.time_zone, @proposal.inserted_at, "%m/%d/%y") %>
        </p>
        <ul class="pt-4 ml-8 list-disc">
          <li>Proposal</li>
          <li>Contract (standard)</li>
          <%= if @proposal.questionnaire_id do %>
            <li>Questionnaire</li>
          <% end %>
        </ul>
        <button class="w-full mt-6 btn-primary" phx-click="open-proposal">View booking proposal</button>
      """
    end
  end
end
