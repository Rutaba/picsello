defmodule PicselloWeb.ShootLive.Shared do
  @moduledoc """
  handlers used by job shoots and booking events
  """
  alias Picsello.Shoot
  import PicselloWeb.Gettext, only: [dyn_gettext: 1]
  import PicselloWeb.LiveHelpers
  import PicselloWeb.FormHelpers
  use Phoenix.Component

  def duration_options() do
    for(duration <- Shoot.durations(), do: {dyn_gettext("duration-#{duration}"), duration})
  end

  def location(assigns) do
    assigns = assign_new(assigns, :allow_location_toggle, fn -> true end)
    assigns = assign_new(assigns, :allow_address_toggle, fn -> true end)
    assigns = assign_new(assigns, :address_field_title, fn -> "Shoot Address" end)
    assigns = assign_new(assigns, :location_field_title, fn -> "Shoot Location" end)
    assigns = assign_new(assigns, :is_edit, fn -> true end)

    ~H"""
    <div class={classes("flex flex-col", %{"sm:col-span-3" => !@address_field, "sm:col-span-2" => @address_field} |> Map.merge(select_invalid_classes(@f, :location)))}>
      <div class="flex items-center justify-between">
        <%= if @allow_location_toggle do %>
          <%= label_for @f, :location, label: @location_field_title %>
          <%= select_field @f, :location, for(location <- Shoot.locations(), do: {location |> Atom.to_string() |> dyn_gettext(), location }), prompt: "Select below",  disabled: !@is_edit  %>
        <% end %>

        <%= if @allow_address_toggle && !@address_field do %>
          <a class="text-xs link" phx-target={@myself} phx-click="address" phx-value-action="add-field">Add an address</a>
        <% end %>
      </div>

      <%!-- TODO: commented on purpose. Remove once design changes are finalized --%>
      <%!-- <%= if @allow_location_toggle do %>
        <%= select_field @f, :location, for(location <- Shoot.locations(), do: {location |> Atom.to_string() |> dyn_gettext(), location }), prompt: "Select below",  disabled: !@is_edit  %>
      <% end %> --%>
    </div>

    <%= if @address_field do %>
      <div class="flex flex-col sm:col-span-2">
        <div class="flex items-center justify-between">
          <%= label_for @f, :address, label: @address_field_title %>

          <%= if @allow_address_toggle do %>
            <a class="text-xs link" phx-target={@myself} phx-click="address" phx-value-action="remove">Remove address</a>
          <% end %>
        </div>

        <%= input @f, :address, phx_hook: "PlacesAutocomplete", autocomplete: "off", placeholder: "Enter a location",  disabled: !@is_edit %>
        <div class="relative autocomplete-wrapper" id="auto-complete" phx-update="ignore"></div>
      </div>
    <% end %>
    """
  end
end
