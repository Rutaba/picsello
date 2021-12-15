defmodule PicselloWeb.Live.Profile.EditColorComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Profiles}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_organization()
    |> assign_changeset(Map.take(assigns, [:color]))
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal !max-w-sm ">
      <h1 class="text-3xl font-bold">Edit color</h1>

      <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>

        <%= for p <- inputs_for(f, :profile) do %>
          <ul class="mt-4 grid grid-cols-4 gap-5 sm:gap-3 max-w-sm">
            <%= for(color <- colors()) do %>
              <li class="aspect-h-1 aspect-w-1">
                <label>
                  <%= radio_button p, :color, color, class: "hidden" %>
                  <div class={classes(
                    "flex cursor-pointer items-center hover:border-base-300 justify-center w-full h-full border rounded", %{
                    "border-base-300" => input_value(p, :color) == color,
                    "hover:border-opacity-40" => input_value(p, :color) != color
                  })}>
                    <div class="w-4/5 rounded h-4/5" style={"background-color: #{color}"}></div>
                  </div>
                </label>
              </li>
            <% end %>
          </ul>
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
          assigns: Enum.into(opts, Map.take(assigns, [:current_user, :color]))
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

  defdelegate colors(), to: Picsello.Profiles
end
