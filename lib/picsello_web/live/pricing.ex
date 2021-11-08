defmodule PicselloWeb.Live.Pricing do
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
  def render(assigns) do
    ~H"""
    <.settings_nav socket={@socket} live_action={@live_action} container_class="sm:pb-0 pb-28">
      <div class="my-5">
        <h1 class="text-2xl font-bold">Gallery Store Pricing</h1>

        <p class="max-w-2xl my-2">
          Get your gallery store set up in a few mintues. You’ll need to decide for each category of products the markup (amout of money) you would like to make when someone orders.
        </p>
      </div>

      <hr class="mb-7"/>

      <ul class="grid grid-cols-1 sm:grid-cols-4 gap-8">
      <%= for label <- ["Prints", "Geeting Cards", "Framed Prints", "Custom Albums", "Books"] do %>
        <li class="border rounded p-5">
          <div class="aspect-w-1 aspect-h-1 w-full rounded bg-base-200">
            <.icon name="prints" class="text-blue-planning-300" />
          </div>

          <h2 class="text-2xl font-bold pt-3"><%= label %></h2>
        </li>
      <% end %>
      </ul>
    </.settings_nav>
    """
  end

  @impl true
  def handle_event("add-package", %{}, %{assigns: assigns} = socket),
    do:
      socket
      |> open_modal(PicselloWeb.PackageLive.WizardComponent, assigns |> Map.take([:current_user]))
      |> noreply()

  @impl true
  def handle_event(
        "edit-package",
        %{"package-id" => package_id},
        %{assigns: %{current_user: current_user, templates: templates}} = socket
      ) do
    package_id = String.to_integer(package_id)

    package = Enum.find(templates, &(&1.id == package_id))

    socket
    |> open_modal(PicselloWeb.PackageLive.WizardComponent, %{
      current_user: current_user,
      package: package
    })
    |> noreply()
  end

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

  defp assign_templates(%{assigns: %{current_user: user}} = socket) do
    socket |> assign(templates: user |> Package.templates_for_user() |> Repo.all())
  end
end
