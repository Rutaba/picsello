defmodule PicselloWeb.GalleryLive.Settings.ExpirationDateComponent do
  @moduledoc false
  use PicselloWeb, :live_component

  alias Picsello.Galleries

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_controls()
    |> assign_options()
    |> assign_valid()
    |> ok
  end

  @impl true
  def handle_event(
        "toggle-never-expires",
        _,
        %{assigns: %{is_never_expires: is_never_expires}} = socket
      ) do
    socket
    |> assign(is_never_expires: !is_never_expires)
    |> react_form()
  end

  @impl true
  def handle_event(
        "update-options",
        %{"date" => %{"month" => ""}, "_target" => ["date", "month"]},
        socket
      ) do
    socket
    |> assign(:is_valid, false)
    |> noreply()
  end

  @impl true
  def handle_event(
        "update-options",
        %{"date" => %{"day" => ""}, "_target" => ["date", "day"]},
        socket
      ) do
    socket
    |> assign(:is_valid, false)
    |> noreply()
  end

  @impl true
  def handle_event(
        "update-options",
        %{"date" => %{"year" => ""}, "_target" => ["date", "year"]},
        socket
      ) do
    socket
    |> assign(:is_valid, false)
    |> noreply()
  end

  @impl true
  def handle_event(
        "update-options",
        %{"date" => %{"day" => day}, "_target" => ["date", "day"]},
        socket
      ) do
    socket
    |> assign(day: day |> String.to_integer())
    |> react_form()
  end

  @impl true
  def handle_event(
        "update-options",
        %{"date" => %{"month" => month}, "_target" => ["date", "month"]},
        socket
      ) do
    socket
    |> assign(month: month |> String.to_integer())
    |> react_form()
  end

  @impl true
  def handle_event(
        "update-options",
        %{"date" => %{"year" => year}, "_target" => ["date", "year"]},
        socket
      ) do
    socket
    |> assign(year: year |> String.to_integer())
    |> react_form()
  end

  def handle_event("update-options", _, socket) do
    noreply(socket)
  end

  def handle_event(
        "save",
        _,
        %{
          assigns: %{
            is_never_expires: is_never_expires,
            month: month,
            day: day,
            year: year,
            gallery: gallery
          }
        } = socket
      ) do
    datetime =
      if is_never_expires do
        never_date()
      else
        {:ok, date} = Date.new(year, month, day)
        DateTime.new!(date, ~T[12:00:00], "Etc/UTC")
      end

    {:ok, gallery} = Galleries.set_expire(gallery, %{expired_at: datetime})

    send(self(), :expiration_saved)

    socket
    |> assign(:gallery, gallery)
    |> assign_controls()
    |> react_form()
  end

  defp react_form(socket),
    do:
      socket
      |> assign_options()
      |> assign_valid()
      |> noreply()

  defp assign_controls(%{assigns: %{gallery: %{expired_at: expires}}} = socket) do
    is_set = !is_nil(expires)
    is_never_expires = is_set && DateTime.compare(expires, never_date()) == :eq

    {year, month, day} =
      if is_set and !is_never_expires do
        expires
        |> DateTime.to_date()
        |> split_date()
      else
        {nil, nil, nil}
      end

    socket
    |> assign(
      is_never_expires: is_never_expires,
      year: year,
      month: month,
      day: day
    )
  end

  defp assign_options(%{assigns: %{is_never_expires: true}} = socket) do
    socket
    |> assign(
      month_options: [],
      day_options: [],
      year_options: []
    )
  end

  defp assign_options(%{assigns: %{year: year, month: month}} = socket) do
    date_now = split_date(today())

    socket
    |> assign(
      year_options: year_options(date_now, month),
      month_options: month_options(date_now, year),
      day_options: days_options(date_now, year, month)
    )
  end

  defp year_options({year_now, month_now, _day_now}, month) do
    if !is_nil(month) and month < month_now do
      (year_now + 1)..(year_now + 5)
    else
      year_now..(year_now + 5)
    end
  end

  defp month_options({year_now, month_now, _day_now}, year) do
    if year == year_now do
      month_now..12
    else
      1..12
    end
    |> Enum.map(fn x -> {month_names()[x], x} end)
  end

  @non_leap_year 1999

  defp days_options({year_now, month_now, day_now}, year, month) do
    cond do
      year == year_now and month == month_now ->
        day_now..Calendar.ISO.days_in_month(year, month)

      !is_nil(month) and !is_nil(year) ->
        1..Calendar.ISO.days_in_month(year, month)

      !is_nil(month) and is_nil(year) ->
        1..Calendar.ISO.days_in_month(@non_leap_year, month)

      true ->
        1..28
    end
  end

  defp assign_valid(
         %{
           assigns: %{
             is_never_expires: is_never_expires,
             year: year,
             month: month,
             day: day,
             gallery: %{expired_at: expires}
           }
         } = socket
       ) do
    is_valid =
      valid_checkbox?(is_never_expires, expires) or
        valid_date_controls?([year, month, day], expires)

    socket
    |> assign(:is_valid, is_valid)
  end

  defp valid_checkbox?(false, _), do: false
  defp valid_checkbox?(true, nil), do: true

  defp valid_checkbox?(true, expires),
    do: :eq != Date.compare(DateTime.to_date(never_date()), DateTime.to_date(expires))

  defp valid_date_controls?([year, month, day] = date, expires),
    do:
      Enum.all?(date) and
        Date.compare(Date.new!(year, month, day), today()) != :lt and
        (is_nil(expires) or
           Date.compare(Date.new!(year, month, day), DateTime.to_date(expires)) != :eq)

  defp month_names(),
    do: %{
      1 => "January",
      2 => "February",
      3 => "March",
      4 => "April",
      5 => "May",
      6 => "June",
      7 => "July",
      8 => "August",
      9 => "September",
      10 => "October",
      11 => "November",
      12 => "December"
    }

  defp today(), do: Date.utc_today()

  defp split_date(%Date{} = date), do: date |> Date.to_erl()

  @doc """
  This is hardcoded date of `never`

  It is need to mark `never expires` state for gallery.
  Nil is used to mark not set yet date.
  This way `never expires` date is just a date in far future, at least 100+ years ahead
  """
  def never_date() do
    {:ok, date} = DateTime.new(~D[3022-02-01], ~T[12:00:00], "Etc/UTC")
    date
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h3>Expiration date</h3>
      <.form let={f} for={:date} phx-change="update-options" phx-submit="save" phx-target={@myself} id="updateGalleryExpirationForm">
        <div class="flex justify-between">
          <%= select_field f, :month, @month_options, prompt: "Month", value: @month, class: "border-blue-planning-300 w-1/3 #{@is_never_expires && 'text-gray-400 border-blue-planning-200'}", disabled: @is_never_expires %>
          <%= select_field f, :day, @day_options, prompt: "Day", value: @day, class: "border-blue-planning-300 mx-2 md:mx-3 w-1/3 #{@is_never_expires && 'text-gray-400 border-blue-planning-200'}", disabled: @is_never_expires %>
          <%= select_field f, :year, @year_options, prompt: "Year", value: @year, class: "border-blue-planning-300 w-1/3 #{@is_never_expires && 'text-gray-400 border-blue-planning-200'}", disabled: @is_never_expires %>
        </div>
        <div class="flex flex-row-reverse items-center justify-between w-full mt-5 lg:items-start">
            <%= submit "Save", class: "btn-settings w-32 px-11", disabled: !@is_valid, phx_disable_with: "Saving...", id: "saveGalleryExpiration" %>
            <div class="flex items-center" phx-click="toggle-never-expires" phx-target={@myself} id="updateGalleryNeverExpire">
                <input id="neverExpire" type="checkbox" class="w-6 h-6 mr-3 checkbox-exp cursor-pointer"  checked={@is_never_expires} />
                <label class="cursor-pointer">
                    Never expires
                </label>
            </div>
        </div>
      </.form>
    </div>
    """
  end
end
