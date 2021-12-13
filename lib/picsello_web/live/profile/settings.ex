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
        <.card title="Share your profile">
          <fieldset class={"flex flex-col #{unless Profiles.enabled?(@organization), do: "text-base-250" }"}>
            <div {testid("url")} class={"mt-4 font-bold text-input #{if Profiles.enabled?(@organization), do: "select-all", else: "select-none"}"}>
              <%= @profile_url %>
            </div>

            <button disabled={!Profiles.enabled?(@organization)} type="button" class={"self-auto w-auto py-3 mt-4 text-lg font-semibold border disabled:border-base-200 rounded-lg sm:self-end border-base-300 sm:w-36"} id="copy-public-profile-link" data-clipboard-text={@profile_url} phx-hook="Clipboard">
              <div class="hidden p-1 mt-1 text-sm rounded shadow bg-base-100" role="tooltip">Copied!</div>

              Copy Link
            </button>
          </fieldset>
        </.card>

        <.card title="Enable/disable your public profile">
          <p class="mt-4">If for whatever reason you want to hide your public profile, you can disable it here!</p>

          <.form for={:toggle} phx-change="toggle">
            <label class="mt-4 text-2xl flex">
              <input type="checkbox" class="peer hidden" checked={Profiles.enabled?(@organization)} />

              <div class="hidden peer-checked:flex">
                <div class="rounded-full bg-blue-planning-300 border border-base-100 w-16 p-1 flex justify-end mr-4">
                  <div class="rounded-full h-7 w-7 bg-base-100"></div>
                </div>
                Enabled
              </div>

              <div class="flex peer-checked:hidden">
                <div class="rounded-full w-16 p-1 flex mr-4 border border-blue-planning-300">
                  <div class="rounded-full h-7 w-7 bg-blue-planning-300"></div>
                </div>
                Disabled
              </div>
            </label>
          </.form>
        </.card>
      </div>
    </.settings_nav>
    """
  end

  @impl true
  def handle_event("toggle", %{}, %{assigns: %{organization: organization}} = socket) do
    socket |> assign(organization: Profiles.toggle(organization)) |> noreply()
  end

  defp card(assigns) do
    ~H"""
    <div class="flex overflow-hidden border rounded-lg">
      <div class="w-4 border-r bg-blue-planning-300" />

      <div class="flex flex-col w-full p-4">
        <h1 class="text-xl font-bold sm:text-2xl text-blue-planning-300"><%= @title %></h1>

        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end
end
