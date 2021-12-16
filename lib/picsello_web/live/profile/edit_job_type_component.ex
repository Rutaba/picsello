defmodule PicselloWeb.Live.Profile.EditJobTypeComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal !max-w-md ">
      <h1 class="text-3xl font-bold">Edit Photography Types</h1>

      <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>

        <%= for p <- inputs_for(f, :profile) do %>
          <% input_name = input_name(p, :job_types) <> "[]" %>
          <div class="mt-8 grid grid-cols-1 gap-3 sm:gap-5">
            <%= for(job_type <- job_types()) do %>
              <.job_type_option type="checkbox" name={input_name} job_type={job_type} checked={input_value(p, :job_types) |> Enum.member?(job_type)} />
            <% end %>
          </div>
        <% end %>

        <PicselloWeb.LiveModal.footer />
      </.form>
    </div>
    """
  end

  @impl true
  defdelegate update(assigns, socket), to: PicselloWeb.Live.Profile.Shared

  @impl true
  defdelegate handle_event(name, params, socket), to: PicselloWeb.Live.Profile.Shared

  defdelegate job_types(), to: Picsello.Profiles

  def open(socket), do: PicselloWeb.Live.Profile.Shared.open(socket, __MODULE__)
end
