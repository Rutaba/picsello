defmodule PicselloWeb.Live.Profile.Settings do
  @moduledoc false
  use PicselloWeb, :live_view
  import PicselloWeb.Live.User.Settings, only: [settings_nav: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <.settings_nav socket={@socket} live_action={@live_action}>
      <h1 class="mt-4 text-2xl font-bold">Your Public Profile</h1>
      <p class="mt-1">Allow potential clients to contact you directly through a website that we host for you. Customize the type of photography you offer, color, cover photo, etc.</p>
      <hr class="mt-12">
    </.settings_nav>
    """
  end
end
