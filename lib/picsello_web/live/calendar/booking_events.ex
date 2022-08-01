defmodule PicselloWeb.Live.Calendar.BookingEvents do
  @moduledoc false
  use PicselloWeb, :live_view

  import PicselloWeb.Live.Calendar.Shared, only: [back_button: 1]

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="pt-6 px-6 py-2 center-container">
      <div class="flex text-4xl items-center">
        <.back_button to={Routes.calendar_index_path(@socket, :index)} class="lg:hidden"/>
        <.crumbs class="text-base text-base-250">
          <:crumb to={Routes.calendar_index_path(@socket, :index)}>Calendar</:crumb>
          <:crumb>Booking events</:crumb>
        </.crumbs>
      </div>

      <hr class="mt-2 border-white" />

      <div class="flex items-center justify-between lg:mt-2 md:justify-start">
        <div class="flex text-4xl font-bold items-center">
          <.back_button to={Routes.calendar_index_path(@socket, :index)} class="hidden lg:flex mt-2"/>
          Booking events
        </div>
      </div>

      <hr class="my-4 sm:my-10" />
    </div>

    <div class="flex flex-col justify-between flex-auto p-6 center-container lg:flex-none">
      <div class="flex flex-col">
        <h1 class="mt-3 mb-3 text-4xl font-bold lg:text-5xl">Oh hey!</h1>
        <p class="block text-lg lg:text-2xl lg:w-1/2">You don’t have any booking events created at the moment. Booking events allow you to create events and pages to send to your clients so they can sign up for mini-sessions shoots.</p>
      </div>
      <div class="lg:inline-flex">
        <a title="add booking event" href="#" class="flex justify-center mt-5 text-lg px-7 btn-primary">
          Add booking event
        </a>
      </div>
    </div>
    """
  end
end
