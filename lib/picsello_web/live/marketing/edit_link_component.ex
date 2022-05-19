defmodule PicselloWeb.Live.Marketing.EditLinkComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Profiles

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_changeset(assigns)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal !max-w-xl">
      <div class="flex items-start justify-between flex-shrink-0">
        <h1 class="text-3xl font-bold">Edit Link</h1>
        <PicselloWeb.LiveModal.close_x />
      </div>
      <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>

        <%= for p <- inputs_for(f, :profile) do %>
          <%= if @link_id == "website" do  %>
            <.website_field form={p} class="mt-4" placeholder="Add your website…" />
          <% else %>
            <.website_field form={p} class="mt-4" placeholder="Add your website login url…" name={:website_login} show_checkbox={false} label="Where do you login to edit your website?" />
          <% end %>
        <% end %>

        <PicselloWeb.LiveModal.footer />
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"organization" => params}, socket) do
    socket |> assign_changeset(params) |> noreply()
  end

  def handle_event(
        "save",
        %{"organization" => params},
        %{assigns: %{organization: organization}} = socket
      ) do
    case Profiles.update_organization_profile(organization, params) do
      {:ok, organization} ->
        send(socket.parent_pid, {:update_org, organization})
        socket |> close_modal() |> noreply()

      {:error, _} ->
        socket |> noreply()
    end
  end

  def assign_changeset(
        %{assigns: %{organization: organization}} = socket,
        params \\ %{},
        action \\ :validate
      ) do
    changeset =
      organization
      |> Profiles.edit_organization_profile_changeset(params)
      |> Map.put(:action, action)

    assign(socket, changeset: changeset)
  end

  def open(%{assigns: assigns} = socket, link_id),
    do:
      socket
      |> assign_changeset()
      |> open_modal(
        __MODULE__,
        %{
          assigns: assigns |> Map.take([:organization]) |> Map.put(:link_id, link_id)
        }
      )
end
