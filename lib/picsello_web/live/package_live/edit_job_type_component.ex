defmodule PicselloWeb.PackageLive.EditJobTypeComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal !max-w-md ">
      <h1 class="text-3xl font-bold">Edit Photography Types</h1>
      <h1 class="text-lg text-gray-400 font-medium">Manage your photography offerings</h1>
        <div class="mt-4 grid grid-cols-1 gap-3 sm:gap-4">
          <h1 class="font-semibold text-lg text-blue-planning-300"> Enabled </h1>
          <%= for jt <- @organization.organization_job_types do %>
            <% checked = jt.show_on_business? %>
            <%= if checked do %>
              <div phx-click="edit-job-type" phx-value-job-type-id={jt.id} phx-target={@myself}>
                <.job_type_option type="checkbox" name={:job_type} job_type={jt.job_type} checked={true}/>
              </div>
            <% end %>
          <% end %>
        </div>
        <hr class="my-4" />
        <div class="mt-4 grid grid-cols-1 gap-3 sm:gap-4">
          <h1 class="font-semibold text-lg"> Disabled </h1>
          <%= for jt <- @organization.organization_job_types do %>
          <% checked = jt.show_on_business? %>
            <%= if !checked do %>
              <div phx-click="edit-job-type" phx-value-job-type-id={jt.id} phx-target={@myself}>
                <.job_type_option type="checkbox" name={:job_type} job_type={jt.job_type} checked={false} />
              </div>
            <% end %>
          <% end %>
        </div>

        <button id="close" class="btn-secondary w-full mt-8"  title="close" type="button" phx-click="modal" phx-value-action="close">
          Close
        </button>
    </div>
    """
  end

  @impl true
  defdelegate update(assigns, socket), to: PicselloWeb.PackageLive.Shared

  @impl true
  defdelegate handle_event(name, params, socket), to: PicselloWeb.PackageLive.Shared

  defdelegate job_types(), to: Picsello.Profiles

  def open(socket), do: PicselloWeb.PackageLive.Shared.open(socket, __MODULE__)
end
