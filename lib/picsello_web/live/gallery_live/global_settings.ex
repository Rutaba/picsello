defmodule PicselloWeb.GelleryLive.GlobalSettings do
  @moduledoc false
  use PicselloWeb, :live_view

  alias Picsello.{
    Repo,
    Galleries,
    Shoot,
    GlobalGallerySettings
  }

  require Logger

  @impl true
  def mount(params, _session, %{assigns: %{current_user: current_user}} = socket) do
    global_gallery_settings =
      GlobalGallerySettings
      |> Repo.get_by(organization_id: current_user.organization.id)

    gallery =
      Galleries.list_all_galleries_by_organization_query(current_user.organization.id)
      |> Repo.all()

    socket
    |> is_mobile(params)
    |> assign(gallery: gallery)
    |> assign(global_gallery_settings: global_gallery_settings)
    |> assign(is_expiration_date?: false)
    |> assign_controls()
    |> assign_options()
    |> assign_title()
    |> assign(total_days: 0)
    |> ok()
  end

  @impl true
  def handle_event(
        "save",
        %{"global_expiration_days" => %{"month" => month, "day" => day, "year" => year}},
        socket
      ) do
    day = to_int(day)
    month = to_int(month)
    year = to_int(year)
    total_days = day + month * 30 + year * 365

    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      close_label: "No! Go back",
      confirm_event: "set_expire",
      confirm_label: "Yes, set expiration date",
      icon: "warning-orange",
      subtitle:
        "All new galleries will expire #{if day > 0, do: "#{day} Day"} #{if month > 0, do: " #{month} Month "} #{if year > 0, do: " #{year} Year "} after their shoot date. When a gallery expires, a client will not be able to access it again unless you re-enable the individual gallery. ",
      title: "Set Galleries to Never Expire?",
      payload: %{total_days: total_days}
    })

    socket |> noreply()
  end

  def handle_event(
        "validate_days",
        %{"global_expiration_days" => %{"month" => month, "day" => day, "year" => year}},
        socket
      ) do
    day = to_int(day)
    month = to_int(month)
    year = to_int(year)
    total_days = day + month * 30 + year * 365
    socket |> assign(total_days: total_days, day: day, month: month, year: year) |> noreply()
  end

  def handle_event(
        "validate_days",
        _params,
        socket
      ) do
    socket
    |> noreply()
  end

  def handle_event(
        "save",
        %{},
        %{assigns: %{is_never_expires: true}} = socket
      ) do
    socket
    |> PicselloWeb.ConfirmationComponent.open(%{
      close_label: "No! Go back",
      confirm_event: "never_expire",
      confirm_label: "Yes, set galleries to never expire",
      icon: "warning-orange",
      subtitle:
        "New galleries will default to never expire, but you can update a gallery’s expiration date through its individual settings.",
      title: "Set Galleries to Never Expire?"
    })
    |> noreply()
  end

  def handle_event(
        "select_expiration",
        _,
        %{assigns: %{is_expiration_date?: is_expiration_date?}} = socket
      ) do
    socket
    |> assign(is_expiration_date?: !is_expiration_date?)
    |> assign_title()
    |> noreply()
  end

  def handle_event(
        "back_to_menu",
        _,
        socket
      ) do
    socket
    |> assign(is_expiration_date?: false)
    |> assign_title()
    |> noreply()
  end

  @impl true
  def handle_event(
        "toggle-never-expires",
        _,
        %{assigns: %{is_never_expires: is_never_expires}} = socket
      ) do
    socket |> assign(is_never_expires: !is_never_expires) |> noreply()
  end

  defp assign_controls(%{assigns: %{global_gallery_settings: global_gallery_settings}} = socket)
       when not is_nil(global_gallery_settings) do
    if global_gallery_settings.expiration_days != 0 do
      socket |> assign(is_never_expires: false)
    else
      socket |> assign(is_never_expires: true)
    end
  end

  defp assign_controls(socket) do
    socket |> assign(is_never_expires: true)
  end

  defp assign_options(
         %{assigns: %{global_gallery_settings: %{expiration_days: expiration_days}}} = socket
       )
       when not is_nil(expiration_days) do
    year = trunc(expiration_days / 365)
    month = trunc((expiration_days - year * 365) / 30)
    day = trunc(expiration_days - year * 365 - month * 30)
    socket |> assign(day: day, month: month, year: year)
  end

  defp assign_options(socket) do
    socket |> assign(day: "day", month: "month", year: "year")
  end

  defp assign_title(%{assigns: %{is_expiration_date?: is_expiration_date?}} = socket) do
    if(is_expiration_date?) do
      socket |> assign(title: "Global Expiration Days")
    else
      socket |> assign(title: "Gallery Settings")
    end
  end

  defp get_shoots(job_id), do: Shoot.for_job(job_id) |> Repo.all()

  defp to_int(""), do: 0
  defp to_int(value), do: String.to_integer(value)

  @impl true
  def handle_info(
        {:confirm_event, "never_expire"},
        %{
          assigns: %{
            global_gallery_settings: global_gallery_settings,
            gallery: gallery,
            current_user: current_user
          }
        } = socket
      ) do
    global_gallery_settings
    |> case do
      nil -> %GlobalGallerySettings{}
      settings -> settings
    end
    |> Ecto.Changeset.change(%{
      expiration_days: 0,
      organization_id: current_user.organization.id
    })
    |> Repo.insert_or_update()

    gallery
    |> Enum.reject(&(&1.use_global == false))
    |> Enum.each(&(&1 |> Ecto.Changeset.change(%{expired_at: nil}) |> Repo.update!()))

    socket
    |> close_modal()
    |> put_flash(:success, "Settings updated")
    |> assign(day: 0, month: 0, year: 0)
    |> noreply()
  end

  @impl true
  def handle_info(
        {:confirm_event, "set_expire", %{total_days: total_days}},
        socket
      ) do
    socket.assigns.global_gallery_settings
    |> case do
      nil -> %GlobalGallerySettings{}
      settings -> settings
    end
    |> Ecto.Changeset.change(%{
      expiration_days: total_days,
      organization_id: socket.assigns.current_user.organization.id
    })
    |> Repo.insert_or_update()

    socket.assigns.gallery
    |> Enum.reject(&(&1.use_global == false))
    |> Enum.map(fn x ->
      get_shoots(x.job_id)
      |> List.last()
      |> case do
        nil ->
          Ecto.Changeset.change(x, %{expired_at: nil})
          |> Repo.update!()

        shoot ->
          expired_at = Timex.shift(shoot.starts_at, days: total_days) |> Timex.to_datetime()

          Ecto.Changeset.change(x, %{expired_at: expired_at})
          |> Repo.update!()
      end
    end)

    socket
    |> close_modal
    |> put_flash(:success, "Setting Updated")
    |> noreply()
  end

  def card(assigns) do
    assigns = Enum.into(assigns, %{class: "", title_badge: nil})

    ~H"""
    <div class={"flex overflow-hidden border rounded-lg #{@class}"}>
      <div class="w-4 border-r bg-blue-planning-300" />
      <div class="flex flex-col justify-between w-full p-4">
        <div class="flex flex-col items-start sm:items-center sm:flex-row">
          <h1 class="mb-2 mr-4 text-xl font-bold sm:text-2xl text-blue-planning-300"><%= @title %></h1>
          <%= if @title_badge do %>
            <.badge color={:gray}><%= @title_badge %></.badge>
          <% end %>
        </div>
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end
end
