defmodule PicselloWeb.Live.PackageTemplates do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.User.Settings, only: [settings_nav: 1]

  def render(assigns) do
    ~H"""
    <.settings_nav socket={@socket} live_action={@live_action}>
      <div class="flex flex-1 mt-5 flex-col sm:flex-row">
        <div>
          <h1 class="text-2xl font-bold">Photography Package Templates</h1>

          <p class="mt-2">
            You don’t have any packages at the moment.
            (A package is a reusable template to use when creating a potential photoshoot.)
            Go ahead and create your first one!
          </p>
        </div>

        <div class="mt-auto mb-6 flex sm:items-start sm:mt-2 flex-shrink-0 w-full sm:w-auto">
          <a href="#" class="text-center w-full px-8 btn-primary">Add a package</a>
        </div>
      </div>
    </.settings_nav>
    """
  end
end
