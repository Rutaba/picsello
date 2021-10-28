defmodule PicselloWeb.JobLive.NewComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.{Job, Repo}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_changeset()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div class="flex flex-col modal">
        <div class="flex items-start justify-between flex-shrink-0">
          <h1 class="mb-4 text-3xl font-bold">Create a lead</h1>

          <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
            <.icon name="close-x" class="w-3 h-3 stroke-current stroke-2 sm:stroke-1 sm:w-6 sm:h-6"/>
          </button>
        </div>

        <.form for={@changeset} let={f} phx-change="validate" phx-submit="save" phx-target={@myself}>
          <div class="px-1.5 grid grid-cols-1 sm:grid-cols-2 gap-5">
            <%= inputs_for f, :client, fn client_form -> %>
              <%= labeled_input client_form, :name, label: "Client Name", placeholder: "Elizabeth Taylor", phx_debounce: "500" %>
              <%= labeled_input client_form, :email, label: "Client Email", placeholder: "elizabeth@taylor.com", phx_debounce: "500" %>
              <%= labeled_input client_form, :phone, type: :telephone_input, label: "Client Phone", placeholder: "(555) 555-5555", phx_hook: "Phone", phx_debounce: "500" %>
            <% end %>

            <%= labeled_select f, :type, for(type <- Job.types(), do: {humanize(type), type}), label: "Type of Photography", prompt: "Select below" %>

            <div class="sm:col-span-2">
              <div class="flex items-center justify-between mb-2">
                <%= label_for f, :notes, label: "Private Notes" %>
                <.icon_button color="red-sales-300" icon="trash" phx-hook="ClearInput" id="clear-notes" data-input-name={input_name(f,:notes)}>
                  Clear
                </.icon_button>
              </div>
              <%= input f, :notes, type: :textarea, class: "w-full", phx_hook: "AutoHeight", phx_update: "ignore" %>
            </div>
          </div>

          <PicselloWeb.LiveModal.footer>
            <div class="flex flex-col gap-2 sm:flex-row-reverse">
              <button class="px-8 mb-2 sm:mb-0 btn-primary" title="save" type="submit" disabled={!@changeset.valid?} phx-disable-with="Saving...">
                Save
              </button>

              <button class="px-8 btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
                Cancel
              </button>
            </div>
          </PicselloWeb.LiveModal.footer>
        </.form>
      </div>
    """
  end

  @impl true
  def handle_event("validate", %{"job" => params}, socket) do
    socket |> assign_changeset(:validate, params) |> noreply()
  end

  @impl true
  def handle_event("save", %{"job" => params}, socket) do
    changeset = build_changeset(socket, params)

    case changeset |> Repo.insert() do
      {:ok, %Job{id: job_id}} ->
        socket |> push_redirect(to: Routes.job_path(socket, :leads, job_id)) |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  defp build_changeset(
         %{assigns: %{current_user: current_user}},
         params
       ) do
    params
    |> put_in(["client", "organization_id"], current_user.organization_id)
    |> Job.create_changeset()
  end

  defp assign_changeset(
         socket,
         action \\ nil,
         params \\ %{"client" => %{}}
       ) do
    changeset = build_changeset(socket, params) |> Map.put(:action, action)

    assign(socket, changeset: changeset)
  end
end
