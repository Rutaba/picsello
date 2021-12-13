defmodule PicselloWeb.Live.Profile.Settings do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.User.Settings, only: [settings_nav: 1]
  alias Picsello.{Repo, Profiles}

  @impl true
  def mount(_params, _session, %{assigns: %{current_user: user}} = socket) do
    %{organization: %{slug: slug} = organization} = Repo.preload(user, :organization)
    url = Routes.profile_url(socket, :index, slug)
    socket |> assign(profile_url: url, organization: organization) |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.settings_nav socket={@socket} live_action={@live_action}>
      <h1 class="mt-4 text-2xl font-bold">Your Public Profile</h1>
      <p class="mt-1">Allow potential clients to contact you directly through a website that we host for you. Customize the type of photography you offer, color, cover photo, etc.</p>
      <hr class="mt-12">

      <div class="mx-0 mt-14 grid grid-cols-1 lg:grid-cols-2 gap-x-9 gap-y-6">
        <div class="flex overflow-hidden border rounded-lg">
          <div class="w-4 border-r bg-blue-planning-300" />

          <div class="flex flex-col w-full p-4">
            <h1 class="text-xl font-bold sm:text-2xl text-blue-planning-300">Share your profile</h1>

            <input readonly value={@profile_url} class="mt-4 font-bold text-input" />

            <button type="button" class="self-auto w-auto py-3 mt-4 text-lg font-semibold border rounded-lg sm:self-end border-base-300 sm:w-36" id="copy-public-profile-link" data-clipboard-text={@profile_url} phx-hook="Clipboard">
              <div class="hidden p-1 mt-1 text-sm rounded shadow bg-base-100" role="tooltip">Copied!</div>

              Copy Link
            </button>
          </div>
        </div>
      </div>
    </.settings_nav>
    """
  end
end
