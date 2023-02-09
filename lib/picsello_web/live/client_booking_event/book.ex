defmodule PicselloWeb.ClientBookingEventLive.Book do
  @moduledoc false
  use PicselloWeb, live_view: [layout: "live_client"]
  alias Picsello.{BookingEvents, BookingEvent}

  import PicselloWeb.Live.Profile.Shared,
    only: [
      assign_organization_by_slug_on_profile_disabled: 2,
      photographer_logo: 1,
      profile_footer: 1
    ]

  import PicselloWeb.ClientBookingEventLive.DatePicker, only: [date_picker: 1]

  @impl true
  def mount(%{"organization_slug" => slug, "id" => event_id}, session, socket) do
    socket
    |> assign_defaults(session)
    |> assign_organization_by_slug_on_profile_disabled(slug)
    |> assign_booking_event(event_id)
    |> then(fn socket ->
      Picsello.Shoots.subscribe_shoot_change(socket.assigns.organization.id)

      socket
      |> assign_changeset(%{
        "date" => socket.assigns.booking_event |> available_dates() |> Enum.at(0)
      })
    end)
    |> assign_available_times()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="center-container px-8 pt-6 mx-auto min-h-screen flex flex-col">
      <div class="flex">
        <.photographer_logo organization={@organization} />
      </div>
      <hr class="border-gray-100 my-8">

      <div class="sm:mt-6 sm:mx-auto border border-gray-100 flex flex-col p-8 max-w-screen-lg">
        <h1 class="text-3xl font-bold">Booking with <%= @organization.name %></h1>
        <hr class="border-gray-100 my-8">
        <h2 class="text-2xl font-bold">Your details</h2>

        <.form let={f} for={@changeset} phx-change="validate" phx-submit="save">
          <div class="grid gap-5 sm:grid-cols-2 mt-4">
            <%= labeled_input f, :name, label: "Your name", placeholder: "Type your first and last name…", phx_debounce: "500" %>
            <%= labeled_input f, :email, type: :email_input, label: "Your email", placeholder: "Type email…", phx_debounce: "500" %>
            <%= labeled_input f, :phone, type: :telephone_input, label: "Your phone number", placeholder: "Type your phone number…", phx_hook: "Phone", phx_debounce: "500" %>
          </div>

          <hr class="border-gray-100 my-8 sm:my-12">
          <h2 class="text-2xl font-bold mb-2">Pick your session time</h2>

          <div class="grid sm:grid-cols-2 gap-10">
            <.date_picker name={input_name(f, :date)} selected_date={input_value(f, :date)} available_dates={available_dates(@booking_event)} />
            <.time_picker name={input_name(f, :time)} selected_date={input_value(f, :date)} selected_time={input_value(f, :time)} available_times={@available_times} />
          </div>

          <div class="flex flex-col py-6 bg-white gap-5 mt-4 sm:mt-2 sm:flex-row-reverse">
            <button class="btn-primary w-full sm:w-36" title="next" type="submit" disabled={!@changeset.valid?} phx-disable-with="Next">
              Next
            </button>

            <.live_link to={Routes.client_booking_event_path(@socket, :show, @organization.slug, @booking_event.id)} class="btn-secondary flex items-center justify-center w-full sm:w-48">Cancel</.live_link>
          </div>
        </.form>
      </div>

      <hr class="border-gray-100 mt-8 sm:mt-20">

      <.profile_footer color={@color} photographer={@photographer} organization={@organization} />
    </div>
    """
  end

  defp time_picker(assigns) do
    ~H"""
    <div {testid("time_picker")}>
      <%= if @selected_time do %>
        <input type="hidden" name={@name} value={@selected_time} />
      <% end %>
      <%= if @selected_date do %>
        <p class="font-semibold"><%= @selected_date |> Calendar.strftime("%A, %B %-d") %></p>
      <% end %>
      <div class="max-h-96 overflow-auto px-4">
        <%= if Enum.empty?(@available_times) do %>
          <p class="mt-2">No available times</p>
        <% end %>
        <%= for time <- @available_times do %>
          <label class={classes("flex items-center justify-center border border-black py-3 my-4 cursor-pointer", %{"bg-black text-white" => Time.compare(time, @selected_time || Time.utc_now) == :eq})}>
            <%= time |> Calendar.strftime("%-I:%M%P") %>
            <input type="radio" name={@name} value={time} class="hidden" />
          </label>
        <% end %>
      </div>
    </div>
    """
  end

  defp assign_booking_event(%{assigns: %{organization: organization}} = socket, event_id) do
    socket
    |> assign(booking_event: BookingEvents.get_booking_event!(organization.id, event_id))
  end

  @impl true
  def handle_event("validate", %{"booking" => params, "_target" => ["booking", "date"]}, socket) do
    socket
    |> assign_changeset(params |> Map.put("time", nil), :validate)
    |> assign_available_times()
    |> noreply()
  end

  @impl true
  def handle_event("validate", %{"booking" => params}, socket) do
    socket |> assign_changeset(params, :validate) |> noreply()
  end

  @impl true
  def handle_event("save", %{"booking" => params}, socket) do
    %{
      assigns: %{
        changeset: changeset,
        booking_event: booking_event,
        available_times: available_times
      }
    } =
      socket
      |> assign_changeset(params, :validate)
      |> assign_available_times()

    with booking <- current(changeset),
         {:available, true} <- {:available, time_available?(booking, available_times)},
         {:ok, %{proposal: proposal, shoot: shoot}} <-
           BookingEvents.save_booking(booking_event, booking) do
      Picsello.Shoots.broadcast_shoot_change(shoot)

      socket
      |> push_redirect(to: Picsello.BookingProposal.path(proposal.id))
      |> noreply()
    else
      {:available, false} ->
        socket
        |> put_flash(:error, "This time is not available anymore")
        |> noreply()

      _ ->
        socket
        |> put_flash(:error, "Couldn't book this event.")
        |> noreply()
    end
  end

  def handle_info({:shoot_updated, _shoot}, socket) do
    socket
    |> assign_available_times()
    |> noreply()
  end

  defp assign_changeset(socket, params, action \\ nil) do
    changeset = params |> BookingEvents.Booking.changeset() |> Map.put(:action, action)
    assign(socket, changeset: changeset)
  end

  defp available_dates(%BookingEvent{disabled_at: %DateTime{}}), do: []

  defp available_dates(booking_event) do
    booking_event
    |> Map.get(:dates)
    |> Enum.map(& &1.date)
    |> Enum.sort_by(& &1, Date)
    |> Enum.filter(fn date ->
      Date.compare(date, Date.utc_today()) != :lt
    end)
  end

  defp time_available?(booking, available_times) do
    Enum.any?(available_times, &(Time.compare(&1, booking.time) == :eq))
  end

  defp assign_available_times(
         %{assigns: %{booking_event: booking_event, changeset: changeset}} = socket
       ) do
    booking = current(changeset)
    times = BookingEvents.available_times(booking_event, booking.date)
    socket |> assign(available_times: times)
  end

  def current(%{source: changeset}), do: current(changeset)
  def current(changeset), do: Ecto.Changeset.apply_changes(changeset)
end
