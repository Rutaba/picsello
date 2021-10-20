defmodule PicselloWeb.Live.PackageTemplates do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.User.Settings, only: [settings_nav: 1]
  alias Picsello.{Package, Repo}

  @impl true
  def mount(_params, _session, socket) do
    socket |> assign_templates() |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.settings_nav socket={@socket} live_action={@live_action} container_class="sm:pb-0 pb-28">
      <div class={classes("flex flex-col justify-between flex-1 mt-5 sm:flex-row", %{"flex-grow-0" => Enum.any?(@templates) })}>
        <div>
          <h1 class="text-2xl font-bold">Photography Package Templates</h1>

          <p class="my-2">
            <%= if Enum.empty? @templates do %>
              You don’t have any packages at the moment.
              (A package is a reusable template to use when creating a potential photoshoot.)
              Go ahead and create your first one!
            <% else %>
              Create reusable pricing and shoot templates to make it easier to manage your contracts
            <% end %>
          </p>
        </div>

        <div class="fixed bottom-0 left-0 right-0 flex flex-shrink-0 w-full p-6 mt-auto bg-white sm:mt-0 sm:bottom-auto sm:static sm:items-start sm:w-auto">
          <a href="#" class="w-full px-8 text-center btn-primary">Add a package</a>
        </div>
      </div>

      <%= unless Enum.empty? @templates do %>
        <hr class="my-4" />

        <div class="my-4 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-7">
          <%= for template <- @templates do %>
          <div class="p-4 border rounded cursor-pointer hover:bg-blue-planning-100 hover:border-blue-planning-300 group">
            <h1 class="text-2xl font-bold line-clamp-2"><%= template.name %></h1>

            <p class="line-clamp-2"><%= template.description %></p>

            <dl class="flex flex-row-reverse items-center justify-end mt-2">
              <dt class="ml-2 text-gray-500">Downloadable photos</dt>

              <dd class="flex items-center justify-center w-8 h-8 text-xs font-bold bg-gray-200 rounded-full group-hover:bg-white">
                <%= template.download_count %>
              </dd>
            </dl>

            <dl class="flex flex-row-reverse items-center justify-end mt-2">
              <dt class="ml-2 text-gray-500">Print credits</dt>

              <dd class="flex items-center justify-center w-8 h-8 text-xs font-bold bg-gray-200 rounded-full group-hover:bg-white">
                0
              </dd>
            </dl>

            <hr class="my-4" />

            <div class="flex items-center justify-between">
              <div class="text-gray-500"><%= dyn_gettext template.job_type %></div>

              <div class="text-lg font-bold">
                <%= template |> Package.price() |> Money.to_string(fractional_unit: false) %>
              </div>
            </div>
          </div>
          <% end %>
        </div>
      <% end %>
    </.settings_nav>
    """
  end

  defp assign_templates(%{assigns: %{current_user: user}} = socket) do
    socket |> assign(templates: user |> Package.templates_for_user() |> Repo.all())
  end
end
