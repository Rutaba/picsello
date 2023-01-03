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
    |> ok
  end

  @impl true
  def handle_event(
        "toggle-never-expires",
        _,
        %{assigns: %{is_never_expires: is_never_expires}} = socket
      ) do
    if socket.assigns.gallery.disabled,
      do: socket,
      else:
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
        nil
      else
        {:ok, date} = Date.new(year, month, day)
        DateTime.new!(date, ~T[12:00:00], "Etc/UTC")
      end

    {:ok, gallery} = Galleries.set_expire(gallery, %{expired_at: datetime})

    gallery |> Ecto.Changeset.change(%{use_global: false}) |> Picsello.Repo.update!()

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
      |> noreply()

  defp assign_controls(%{assigns: %{gallery: %{expired_at: expires}}} = socket) do
    {year, month, day} =
      if expires do
        expires
        |> DateTime.to_date()
        |> split_date()
      else
        {nil, nil, nil}
      end

    socket
    |> assign(
      is_never_expires: is_nil(expires),
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

  def save_disabled?(year, month, day, is_never_expires, gallery) do
    (!is_never_expires && !valid_date_controls?([year, month, day], gallery.expired_at)) ||
      ((is_never_expires && is_nil(gallery.expired_at)) || gallery.disabled)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h3>Expiration date</h3>
      <.form let={f} for={:date} phx-change="update-options" phx-submit="save" phx-target={@myself} id="updateGalleryExpirationForm">
        <div class="flex justify-between">
          <%= select_field f, :month, @month_options, id: "month-#{@is_never_expires}", prompt: "Month", value: @month, class: "month border-blue-planning-300 w-1/3 cursor-pointer #{(@is_never_expires || @gallery.disabled) && 'text-gray-400 cursor-default border-blue-planning-200'}", disabled: @is_never_expires || @gallery.disabled %>
          <%= select_field f, :day, @day_options, id: "day-#{@is_never_expires}", prompt: "Day", value: @day, class: "day border-blue-planning-300 mx-2 md:mx-3 w-1/3 cursor-pointer #{(@is_never_expires || @gallery.disabled) && 'text-gray-400 cursor-default border-blue-planning-200'}", disabled: @is_never_expires || @gallery.disabled %>
          <%= select_field f, :year, @year_options, id: "year-#{@is_never_expires}", prompt: "Year", value: @year, class: "year border-blue-planning-300 w-1/3 cursor-pointer #{(@is_never_expires || @gallery.disabled) && 'text-gray-400 cursor-default border-blue-planning-200'}", disabled: @is_never_expires || @gallery.disabled %>
        </div>
        <div {testid("toggle_expiry")} class="flex flex-row-reverse items-center justify-between w-full mt-5 lg:items-start">
            <%= submit "Save", class: "btn-settings w-32 px-11", disabled: save_disabled?(@year, @month, @day, @is_never_expires, @gallery), phx_disable_with: "Saving...", id: "saveGalleryExpiration" %>
            <div class="flex items-center" phx-click="toggle-never-expires" phx-target={@myself} id="updateGalleryNeverExpire">
                <input id="neverExpire" disabled={@gallery.disabled} type="checkbox" class="w-6 h-6 mr-3 checkbox-exp cursor-pointer" checked={@is_never_expires} />
                <label class={classes("cursor-pointer", %{"text-gray-400 cursor-default" => @gallery.disabled})}>
                    Never expires
                </label>
            </div>
        </div>
      </.form>
    </div>
    """
  end
end
