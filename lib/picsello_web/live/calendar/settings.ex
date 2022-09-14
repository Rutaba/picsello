defmodule PicselloWeb.Live.Calendar.Settings do
  @moduledoc false
  use PicselloWeb, :live_view

  alias PicselloWeb.Endpoint
  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> ok()
  end

  @impl true
  def render(%{current_user: user} = assigns) do
    url =
      Routes.i_calendar_url(
        assigns.socket,
        :index,
        Phoenix.Token.sign(Endpoint, "USER_ID", user.id)
      )

    ~H"""
    <div class="pt-6 px-6 py-2 center-container">
      <div class="flex text-4xl items-center">
        <.back_button to={Routes.calendar_index_path(@socket, :index)} class="lg:hidden"/>
        <.crumbs class="text-base text-base-250">
          <:crumb to={Routes.calendar_index_path(@socket, :index)}>Calendar</:crumb>
          <:crumb>Settings</:crumb>
        </.crumbs>
      </div>

      <hr class="mt-2 border-white" />

      <div class="flex items-center justify-between lg:mt-2 md:justify-start">
        <div class="flex text-4xl font-bold items-center">
          <.back_button to={Routes.calendar_index_path(@socket, :index)} class="hidden lg:flex mt-2"/>
          Calendar Settings
        </div>
      </div>
    </div>

    <hr class="my-4 sm:my-10" />

    <div class="px-6 center-container">
      <div class="grid lg:grid-cols-2 grid-cols-1 gap-x-20">
        <div class="grid-col items-center flex-col py-4 lg:mt-0 mt-6 text-xl lg:order-first order-last">
          <b>Subscribe to your Picsello calendar using an external provider:</b><br>
          Copy this link if you need to subscribe to your the Picsello calendar from another provider. They need to use the ICAL protocol.

          <div class="flex flex-col my-7">
            <div {testid("url")} class="text-input text-clip overflow-hidden"><%= url %></div>
          </div>

          <.icon_button icon="anchor" color="blue-planning-300" class="flex-shrink-0 transition-colors text-blue-planning-300" id="copy-calendar-link" data-clipboard-text={url} phx-hook="Clipboard">
            <span>Copy link</span>
            <div class="hidden p-1 text-sm rounded shadow" role="tooltip">
              Copied!
            </div>
           </.icon_button>
        </div>
        <div class="mt-4 grid-col order-first lg:order-last">
          <div class="flex flex-row items-center md:px-20 px-10 bg-base-200 rounded-lg">
            <div>
              <.icon name="picsello" class="w-12 h-12 bg-white rounded p-2"/>
              <div class="absolute ml-[34px] -mt-[25px] md:ml-[42px] md:-mt-[30px] bg-blue-planning-300 rounded-full w-3 h-3"></div>
            </div>
            <div class="flex w-full">
              <.icon name="long-right-arrow" class="text-blue-planning-300 px-2 w-full"/>
            </div>
            <div>
              <.icon name="calendar" class="w-12 h-12 bg-white rounded p-2"/>
              <div class="absolute -ml-[5px] -mt-[25px] md:-mt-[30px] bg-blue-planning-300 rounded-full w-3 h-3"></div>
            </div>
          </div>
        </div>

      </div>

    </div>
    """
  end
end
