defmodule PicselloWeb.Calendar.Shared.DetailComponent do
  use Phoenix.Component
  import PicselloWeb.LiveHelpers
  import Phoenix.LiveComponent

  def section(%{opts: %{calender: "internal"}} = assigns) do
    ~H"""
      <div class="pt-4 flex flex-col">
        <.date_time_item opts={@opts} />

        <%= if @opts.location && @opts.address do %>
          <.event_item icon="vector" item_title={@opts.address} item_desc={to_string(@opts.location) |> String.replace("_", " ") |> String.capitalize()} />
        <% end %>

        <.event_item icon="phone" item_title={@opts.client_name} item_desc={@opts.client_phone} />
        <.event_item icon="calendar" icon_class="mt-1" item_title="Picsello Calendar" item_desc="Created by: Picsello" />
      </div>

      <%= live_redirect to: @opts.url do %>
        <button class={"w-full mt-6 " <> @confirm_class} type="button" phx-disable-with="Saving&hellip;">
          View Job
        </button>
      <% end %>
    """
  end

  def section(%{opts: %{calender: "external"}} = assigns) do
    ~H"""
      <div class="pt-4 flex flex-col">
        <.date_time_item opts={@opts} />

        <%= if @opts.conferencing do %>
          <.event_item icon="vector" custom_item={true}>
            <div class="mt-1 font-bold text-base"> <%=@opts.conferencing["details"]["url"] %> </div>
          </.event_item>
        <% end %>

        <%= if @opts.description do %>
          <.event_item icon="description" custom_item={true}>
            <div class="font-normal text-base"> You have been invited to schedule meeting </div>
            <div class="mt-1 font-normal text-base"> <%= @opts.description %> </div>
          </.event_item>
        <% end %>

        <.event_item icon="attending" custom_item={true}>
          <div class="font-bold text-base"> Attending </div>
          <div class="text-sm w-fit rounded bg-emerald-300 font-semibold text-emerald-600 px-1">
            <%= @opts.status == "confirmed" && "Yes" || "No" %>
          </div>
        </.event_item>

        <.event_item icon="calendar" item_title="Home Calendar" item_desc={"Created by: #{@opts.organizer_email}"} />
      </div>

      <.link href={@opts.url} target="_blank">
        <button class={"w-full mt-6 flex justify-center " <> @confirm_class} type="button">
          Open in calendar
          <.icon name="new-window" class="ml-2 mt-1.5 w-3 h-4" />
        </button>
      </.link>
    """
  end

  defp date_time_item(assigns) do
    ~H"""
      <.event_item
        icon="clock"
        item_title={"#{Timex.weekday(@opts.start_date) |> Timex.day_name()}, #{@opts.start_date.month |> Timex.month_name() |> String.capitalize()} #{@opts.start_date.day}"}
        item_desc={"#{normalize_datetime(@opts.start_date)} - #{normalize_datetime(@opts.end_date)}"}
        class="bg-base-200 mx-[-31px] px-6"
        font_size="text-xl"
      />
    """
  end

  defp normalize_datetime(%DateTime{} = datetime) do
    {:ok, time} = datetime |> DateTime.to_time() |> Timex.format("{h12}:{0m} {am}")
    time
  end

  defp normalize_datetime(_datetime), do: "---"

  defp event_item(assigns) do
    assigns =
      Enum.into(assigns, %{
        class: "",
        custom_item: false,
        icon_class: "mt-2",
        font_size: "text-base"
      })

    ~H"""
    <div class={"flex gap-2 py-2 #{@class}"}>
      <.icon name={@icon} class={"#{@icon_class} w-7 h-7 text-blue-planning-300"} />
      <div>
        <%= if @custom_item do %>
          <%= render_slot(@inner_block) %>
        <% else %>
          <div class={"font-bold #{@font_size}"}> <%= @item_title %> </div>
          <div class={"font-normal #{@font_size}"}> <%= @item_desc %> </div>
        <% end %>
      </div>
    </div>
    """
  end
end
