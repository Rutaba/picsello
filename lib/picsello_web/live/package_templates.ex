defmodule PicselloWeb.Live.PackageTemplates do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.User.Settings, only: [settings_nav: 1]
  import PicselloWeb.PackageLive.Shared, only: [package_card: 1]
  alias Picsello.{Package, Repo}

  @impl true
  def mount(_params, _session, socket) do
    socket |> assign_templates() |> ok()
  end

  @impl true
  def handle_params(_, _, %{assigns: %{live_action: :new}} = socket) do
    socket
    |> open_wizard()
    |> noreply()
  end

  @impl true
  def handle_params(
        %{"id" => package_id},
        _,
        %{assigns: %{live_action: :edit, templates: templates}} = socket
      ) do
    package_id = String.to_integer(package_id)
    package = Enum.find(templates, &(&1.id == package_id))

    socket
    |> open_wizard(%{package: package})
    |> noreply()
  end

  @impl true
  def handle_params(_, _, %{assigns: %{live_action: :index}} = socket) do
    socket |> noreply()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.settings_nav socket={@socket} live_action={@live_action} container_class="sm:pb-0 pb-28">
      <div class={classes("flex flex-col justify-between flex-1 mt-5 sm:flex-row", %{"flex-grow-0" => Enum.any?(@templates) })}>
        <div>
          <h1 class="text-2xl font-bold">Photography Package Templates</h1>

          <p class="max-w-2xl my-2">
            <%= if Enum.empty? @templates do %>
              You don’t have any packages at the moment.
              (A package is a reusable template to use when creating a potential photoshoot.)
              Go ahead and create your first one!
            <% else %>
              Create reusable pricing and shoot templates to make it easier to manage your contracts
            <% end %>
          </p>
        </div>

        <div class="fixed bottom-0 left-0 right-0 z-20 flex flex-shrink-0 w-full p-6 mt-auto bg-white sm:mt-0 sm:bottom-auto sm:static sm:items-start sm:w-auto">
          <button type="button" phx-click="add-package" class="w-full px-8 text-center btn-primary">Add a package</button>
        </div>
      </div>

      <%= unless Enum.empty? @templates do %>
        <hr class="my-4" />

        <div class="my-4 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-7">
        <%= for template <- @templates do %>
          <div {testid("package-template-card")} class="relative">
            <div class="absolute z-10 top-6 right-5" data-offset="0" phx-hook="Select" id={"mange-template-#{template.id}"}>
              <button title="Manage" type="button" class="flex flex-shrink-0 p-1 text-2xl font-bold bg-white border rounded border-blue-planning-300 text-blue-planning-300">
                <.icon name="hellip" class="w-4 h-1 m-1 fill-current open-icon text-blue-planning-300" />

                <.icon name="close-x" class="hidden w-3 h-3 mx-1.5 stroke-current close-icon stroke-2 text-blue-planning-300" />
              </button>

              <div class="flex flex-col hidden bg-white border rounded-lg shadow-lg popover-content">
                <button title="Edit" type="button" phx-click="edit-package" phx-value-package-id={template.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-blue-planning-100 hover:font-bold">
                  <.icon name="pencil" class="inline-block w-4 h-4 mr-3 fill-current text-blue-planning-300" />
                  Edit
                </button>

                <button title="Archive" type="button" phx-click="confirm-archive-package" phx-value-package-id={template.id} class="flex items-center px-3 py-2 rounded-lg hover:bg-red-sales-100 hover:font-bold">
                  <.icon name="trash" class="inline-block w-4 h-4 mr-3 fill-current text-red-sales-300" />
                  Archive
                </button>
              </div>
            </div>

            <div phx-click="edit-package" phx-value-package-id={template.id} class="h-full"><.package_card package={template} class="h-full"/></div>
          </div>
        <% end %>
        </div>
      <% end %>
    </.settings_nav>
    """
  end

  @impl true
  def handle_event("add-package", %{}, socket),
    do:
      socket
      |> push_patch(to: Routes.package_templates_path(socket, :new))
      |> noreply()

  @impl true
  def handle_event(
        "edit-package",
        %{"package-id" => package_id},
        socket
      ),
      do:
        socket
        |> push_patch(to: Routes.package_templates_path(socket, :edit, package_id))
        |> noreply()

  @impl true
  def handle_event("confirm-archive-package", %{"package-id" => package_id}, socket),
    do:
      socket
      |> assign(:archive_package_id, package_id)
      |> PicselloWeb.ConfirmationComponent.open(%{
        close_label: "No! Get me out of here",
        confirm_event: "archive",
        confirm_label: "Yes, archive",
        icon: "warning-orange",
        subtitle:
          "Archiving a package template doesn’t affect active leads or jobs—this will remove the option to create anything with this package template.",
        title: "Are you sure you want to archive this package template?"
      })
      |> noreply()

  @impl true
  def handle_info(
        {:confirm_event, "archive"},
        %{assigns: %{archive_package_id: package_id}} = socket
      ) do
    with %Package{} = package <- Repo.get(Package, package_id),
         {:ok, _package} <- package |> Package.archive_changeset() |> Repo.update() do
      socket
      |> assign_templates()
      |> put_flash(:success, "The package has been archived")
      |> close_modal()
      |> noreply()
    else
      _ ->
        socket
        |> put_flash(:error, "Failed to archive package")
        |> noreply()
    end
  end

  @impl true
  def handle_info({:update, _package}, socket) do
    socket
    |> assign_templates()
    |> put_flash(:success, "The package has been successfully saved")
    |> noreply()
  end

  @impl true
  def handle_info({:wizard_closed, _modal}, %{assigns: assigns} = socket) do
    assigns
    |> Map.get(:flash, %{})
    |> Enum.reduce(socket, fn {kind, msg}, socket -> put_flash(socket, kind, msg) end)
    |> push_patch(to: Routes.package_templates_path(socket, :index))
    |> noreply()
  end

  defp assign_templates(%{assigns: %{current_user: user}} = socket) do
    socket |> assign(templates: user |> Package.templates_for_user() |> Repo.all())
  end

  defp open_wizard(socket, assigns \\ %{}) do
    socket
    |> open_modal(PicselloWeb.PackageLive.WizardComponent, %{
      close_event: :wizard_closed,
      assigns: Enum.into(assigns, Map.take(socket.assigns, [:current_user]))
    })
  end
end
