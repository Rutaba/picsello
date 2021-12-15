defmodule PicselloWeb.Live.Profile.EditJobTypeComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Profiles}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_organization()
    |> assign_changeset(Map.take(assigns, [:job_types]))
    |> ok()
  end

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

        <PicselloWeb.LiveModal.footer>
          <button class="btn-primary" title="save" type="submit" phx-disable-with="Save">
            Save
          </button>

          <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
            Cancel
          </button>
        </PicselloWeb.LiveModal.footer>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"organization" => params}, socket) do
    socket |> assign_changeset(params) |> noreply()
  end

  @impl true
  def handle_event("validate", _params, socket) do
    socket |> assign_changeset(%{"profile" => %{"job_types" => []}}) |> noreply()
  end

  @impl true
  def handle_event(
        "save",
        %{"organization" => params},
        %{assigns: %{organization: organization}} = socket
      ) do
    case Profiles.update_organization_profile(organization, params) do
      {:ok, organization} ->
        send(socket.parent_pid, {:update, organization})
        socket |> close_modal() |> noreply()

      {:error, _} ->
        socket |> noreply()
    end
  end

  def open(%{assigns: assigns} = socket, opts \\ %{}),
    do:
      open_modal(
        socket,
        __MODULE__,
        %{
          assigns: Enum.into(opts, Map.take(assigns, [:current_user, :job_types]))
        }
      )

  defp assign_changeset(
         %{assigns: %{organization: organization}} = socket,
         params,
         action \\ :validate
       ) do
    changeset =
      organization
      |> Profiles.edit_organization_profile_changeset(params)
      |> Map.put(:action, action)

    assign(socket, changeset: changeset)
  end

  defp assign_organization(%{assigns: %{current_user: current_user}} = socket) do
    organization = Profiles.find_organization_by(user: current_user)
    socket |> assign(:organization, organization)
  end

  defdelegate job_types(), to: Picsello.Profiles
end
