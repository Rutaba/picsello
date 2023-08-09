defmodule PicselloWeb.Live.Brand.CustomizeClientProposalComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Organization, Repo}
  import PicselloWeb.Shared.Quill, only: [quill_input: 1]

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
          <h1 class="mb-4 text-3xl font-bold">
            Customize client proposal
          </h1>
          <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
            <.icon name="close-x" class="w-3 h-3 stroke-current stroke-2 sm:stroke-1 sm:w-6 sm:h-6"/>
          </button>
        </div>
        <.form for={@changeset} :let={f} phx-change="validate" phx-submit="save" phx-target={@myself}>
          <%= for e <- inputs_for(f, :client_proposal) do %>
            <div class="grid mt-4 grid-cols-1 sm:grid-cols-2 gap-5 sm:gap-12 mb-6">
              <div>
                <%= labeled_input e, :title, spellcheck: "true", default: "Welcome", label: "Title"%>
                <p class="text-base-250">Write a short and sweet title to welcome your client</p>
              </div>
              <div>
                <%= labeled_input e, :booking_panel_title, spellcheck: "true", default: "Here's how you get your show booked:", label: "Booking Panel Title"%>
                <p class="text-base-250">Write a statement to prompt your client to book</p>
              </div>
            </div>
            <div>
              <div class="input-label">Message</div>
              <.quill_input f={e} html_field={:message}, placeholder="Start typing…" />
              <p class="text-base-250 sm:mr-32">Write an intro about you, your work and business</p>
              <div class="mt-6">
                <%= labeled_input e, :contact_button, spellcheck: "true", default: "Message ABC", label: "Contact Button"%>
                <p class="text-base-250 sm:mr-32">Customize what you'd like your contact button to say</p>
              </div>
            </div>
          <% end %>
          <PicselloWeb.LiveModal.footer disabled={!@changeset.valid?} />
        </.form>
      </div>
    """
  end

  @impl true
  def handle_event(
        "validate",
        %{"organization" => params},
        socket
      ),
      do:
        socket
        |> assign_changeset(:validate, params)
        |> noreply()

  @impl true
  def handle_event("save", %{"organization" => params}, socket) do
    case socket |> build_changeset(params) |> Repo.update() do
      {:ok, organization} ->
        send(socket.parent_pid, {:update, organization, "Client Proposal saved"})
        socket |> close_modal() |> noreply()

      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> noreply()
    end
  end

  defp build_changeset(
         %{
           assigns: %{
             organization: organization,
             default_client_proposal_params: default_client_proposal_params
           }
         },
         params
       ) do
    if is_nil(organization.client_proposal) do
      updated_organization =
        Organization.client_proposal_portal_changeset(
          organization,
          default_client_proposal_params
        )
        |> current_organization()

      Organization.client_proposal_portal_changeset(updated_organization, params)
    else
      Organization.client_proposal_portal_changeset(organization, params)
    end
  end

  defp current_organization(changeset), do: Ecto.Changeset.apply_changes(changeset)

  defp assign_changeset(socket, action \\ nil, params \\ %{})

  defp assign_changeset(socket, :validate, params) do
    changeset =
      socket
      |> build_changeset(params)
      |> Map.put(:action, :validate)

    assign(socket, changeset: changeset)
  end

  defp assign_changeset(socket, action, params) do
    changeset = build_changeset(socket, params) |> Map.put(:action, action)

    assign(socket, changeset: changeset)
  end

  def open(
        %{
          assigns: %{
            current_user: current_user,
            default_client_proposal_params: default_client_proposal_params
          }
        } = socket,
        organization
      ) do
    socket
    |> open_modal(__MODULE__, %{
      current_user: current_user,
      organization: organization,
      default_client_proposal_params: default_client_proposal_params
    })
  end
end
