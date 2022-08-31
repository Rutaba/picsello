defmodule PicselloWeb.ClientBookingEventLive.DatePicker do
  @moduledoc false
  use PicselloWeb, :live_component

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_month()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-wrapper"} class="w-full">
      <%= if @selected_date do %>
        <input type="hidden" name={@name} value={@selected_date} />
      <% end %>
      <div class="flex items-center">
        <p class="font-semibold"><%= @month |> Calendar.strftime("%B %Y") %></p>
        <button type="button" phx-click="todays-month" phx-target={@myself} title="today" class="h-9 text-white bg-black ml-auto py-2 px-4 disabled:opacity-60" disabled={same_month?(Date.utc_today(), @month)}>Today</button>
        <button type="button" phx-click="previous-month" phx-target={@myself} title="previous month" class="h-9 text-white bg-black aspect-square mx-2 flex items-center justify-center" phx-click="previous-month" phx-target={@myself}><.icon name="back" class="w-4 h-4 stroke-3" /></button>
        <button type="button" phx-click="next-month" phx-target={@myself} title="next month" class="h-9 text-white bg-black aspect-square flex items-center justify-center"><.icon name="forth" class="w-4 h-4 stroke-3" /></button>
      </div>
      <hr class="border-gray-100 my-2">
      <div class="grid grid-cols-7 mt-2 gap-2">
        <%= for day_week <- ~w[SUN MON TUE WED THU FRI SAT] do %>
          <div class="text-center text-xs p-2"><%= day_week %></div>
        <% end %>
        <%= for day <- calendar_range(@month) do %>
          <label class={classes("flex items-center justify-center p-2 aspect-square text-gray-400", %{
            "text-white bg-black border border-black cursor-pointer font-semibold" => day == @selected_date,
            "text-black border border-black cursor-pointer font-semibold" => day != @selected_date && day in @available_dates,
            "invisible" => !same_month?(day, @month),
          })}>
            <%= day |> Calendar.strftime("%-d") %>
            <%= if day in @available_dates do %>
              <input type="radio" checked={@selected_date == day} name={@name} value={day} class="hidden" />
            <% end %>
          </label>
        <% end %>
      </div>
    </div>
    """
  end

  def date_picker(assigns) do
    ~H"""
    <.live_component module={__MODULE__} id={assigns[:id] || "date_picker"} {assigns} />
    """
  end

  @impl true
  def handle_event("todays-month", %{}, socket) do
    socket
    |> assign(month: Date.utc_today() |> Date.beginning_of_month())
    |> noreply()
  end

  @impl true
  def handle_event("previous-month", %{}, %{assigns: %{month: month}} = socket) do
    socket
    |> assign(month: month |> Date.add(-1) |> Date.beginning_of_month())
    |> noreply()
  end

  @impl true
  def handle_event("next-month", %{}, %{assigns: %{month: month}} = socket) do
    socket
    |> assign(month: month |> Date.end_of_month() |> Date.add(1))
    |> noreply()
  end

  def calendar_range(month) do
    start_date = month |> Date.beginning_of_week(:sunday)
    end_date = month |> Date.end_of_month() |> Date.end_of_week(:sunday)
    Date.range(start_date, end_date)
  end

  defp assign_month(%{assigns: %{selected_date: nil}} = socket) do
    socket
    |> assign(month: Date.utc_today() |> Date.beginning_of_month())
  end

  defp assign_month(%{assigns: %{selected_date: date}} = socket) do
    socket
    |> assign(month: date |> Date.beginning_of_month())
  end

  defp same_month?(%Date{month: month1}, %Date{month: month2}), do: month1 == month2
end
