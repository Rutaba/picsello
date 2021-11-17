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

    socket
    |> assign(:gallery, gallery)
    |> assign_controls
    |> react_form
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
      year_options: [],
      month_options: [],
      day_options: []
    )
  end

  defp assign_options(%{assigns: %{year: year, month: month}} = socket) do
    date_now = split_date(tomorrow())

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
        day_now..Date.days_in_month(Date.new!(year, month, day_now))

      !is_nil(month) and !is_nil(year) ->
        1..Date.days_in_month(Date.new!(year, month, day_now))

      !is_nil(month) and is_nil(year) ->
        1..Date.days_in_month(Date.new!(@non_leap_year, month, day_now))

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
             day: day
           }
         } = socket
       ) do
    is_valid =
      is_never_expires or
        (Enum.all?([year, month, day]) and
           Date.compare(Date.new!(year, month, day), tomorrow()) != :lt)

    socket
    |> assign(:is_valid, is_valid)
  end

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

  defp tomorrow(), do: Date.utc_today() |> Date.add(1)

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
end
