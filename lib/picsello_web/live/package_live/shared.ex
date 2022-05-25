defmodule PicselloWeb.PackageLive.Shared do
  @moduledoc """
  handlers used by both package and package templates
  """
  alias Picsello.{
    Package
  }

  import PicselloWeb.Gettext, only: [dyn_gettext: 1]
  use Phoenix.HTML
  import Phoenix.LiveView
  import PicselloWeb.FormHelpers
  import PicselloWeb.LiveHelpers, only: [testid: 1]
  import Phoenix.HTML.Form
  import PicselloWeb.Gettext
  use Phoenix.Component

  @spec package_card(%{
          package: %Package{}
        }) :: %Phoenix.LiveView.Rendered{}
  def package_card(assigns) do
    assigns =
      assigns
      |> Enum.into(%{
        class: ""
      })

    ~H"""
      <div class={"flex flex-col p-4 border rounded cursor-pointer hover:bg-blue-planning-100 hover:border-blue-planning-300 group #{@class}"}>
        <h1 class="text-2xl font-bold line-clamp-2"><%= @package.name %></h1>

        <div class="mb-4 relative" phx-hook="PackageDescription" id={"package-description-#{@package.id}"} data-event="mouseover">
          <div class="line-clamp-2 raw_html raw_html_inline">
            <%= raw @package.description %>
          </div>
          <div class="hidden p-4 text-sm rounded bg-white font-sans shadow my-4 w-full absolute top-2 z-0" data-offset="0" role="tooltip">
            <div class="line-clamp-6 raw_html"></div>
            <button class="inline-block text-blue-planning-300">View all</button>
          </div>
          <%= if is_package_description_length_long?(@package.description) do %>
            <button class="inline-block text-blue-planning-300 view_more">View more</button>
          <% end %>
        </div>

        <dl class="flex flex-row-reverse items-center justify-end mt-auto">
          <%= if Money.zero?(@package.download_each_price) do %>
            <dt class="text-gray-500">Unlimited Complimentary Downloads</dt>
          <% else %>
            <dt class="text-gray-500">Complimentary Downloads</dt>
            <dd class="flex items-center justify-center w-8 h-8 mr-2 text-xs font-bold bg-gray-200 rounded-full group-hover:bg-white">
              <%= @package.download_count %>
            </dd>
          <% end %>
        </dl>

        <hr class="my-4" />

        <div class="flex items-center justify-between">
          <div class="text-gray-500"><%= dyn_gettext @package.job_type %></div>

          <div class="text-lg font-bold">
            <%= @package |> Package.price() |> Money.to_string(fractional_unit: false) %>
          </div>
        </div>

        <div class="flex items-center justify-between">
          <div class="text-gray-500">Download Price</div>

          <div class="text-lg font-bold">
            <%= if Money.zero?(@package.download_each_price) do %>--<% else %><%= @package.download_each_price %>/each<% end %>
          </div>
        </div>

      </div>
    """
  end

  def package_basic_fields(assigns) do
    ~H"""
    <div class="grid grid-cols-1 sm:grid-cols-3 gap-2 sm:gap-7">
      <%= labeled_input @form, :name, label: "Title", placeholder: "e.g. #{dyn_gettext @job_type} Deluxe", phx_debounce: "500", wrapper_class: "mt-4" %>
      <div class="grid gap-2 grid-cols-2 sm:contents">
        <%= labeled_select @form, :shoot_count, Enum.to_list(1..10), label: "# of Shoots", wrapper_class: "mt-4", class: "py-3", phx_update: "ignore" %>

        <div class="mt-4 flex flex-col">
          <%= label_for @form, :turnaround_weeks, label: "Image Turnaround Time" %>

          <div>
            <%= input @form, :turnaround_weeks, type: :number_input, phx_debounce: "500", class: "w-1/3 text-center pl-6 mr-4", min: 1, max: 52 %>

            <%= ngettext("week", "weeks", Ecto.Changeset.get_field(@form.source, :turnaround_weeks)) %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def digital_download_fields(assigns) do
    ~H"""
    <% d = form_for(@download, "#") %>
    <div class="mt-6 sm:mt-9"  {testid("download")}>
      <h2 class="mb-2 text-xl font-bold justify-self-start sm:mr-4 whitespace-nowrap">Digital Downloads</h2>
      <%= if d |> current() |> Map.get(:is_enabled) do %>
        Digital downloads are valued at <b><%= download_price(@package_form) %></b> / ea
      <% end %>
    </div>
    <div class="flex flex-col w-full mt-3">
      <label class="flex items-center">
        <%= radio_button(d, :is_enabled, true, class: "w-5 h-5 mr-2 radio") %>
        Charge for downloads
      </label>
      <%= if d |> current() |> Map.get(:is_enabled) do %>
        <div class="flex flex-col ml-7">
          <label class="flex items-center mt-3">
            <%= checkbox(d, :is_custom_price, class: "w-5 h-5 mr-2.5 checkbox") %>
            Set my own download price
          </label>
          <%= if d |> current() |> Map.get(:is_custom_price) do %>
            <%= input(d, :each_price, class: "mt-3 w-full sm:w-32 text-lg text-center", phx_hook: "PriceMask") %>
          <% end %>
          <div class="flex flex-col justify-between mt-3 sm:flex-row ">
            <div class="w-full sm:w-auto">
              <label class="flex items-center">
                <%= checkbox(d, :includes_credits, class: "w-5 h-5 mr-2.5 checkbox") %>
                Include download credits
              </label>
              <%= if d |> current() |> Map.get(:includes_credits), do: input(d, :count, placeholder: 1, class: "mt-3 w-full sm:w-28 text-lg text-center") %>
            </div>
          </div>
          <% p = form_for(@package_pricing, "#") %>
          <label class="flex items-center mt-3">
            <%= checkbox(p, :is_buy_all, class: "w-5 h-5 mr-2.5 checkbox") %>
            Set a "buy them all" price
          </label>
          <%= if p |> current() |> Map.get(:is_buy_all) do %>
            <%= input(@package_form, :buy_all, placeholder: "$750.00", class: "mt-3 w-full sm:w-32 text-lg text-center", phx_hook: "PriceMask") %>
          <% end %>
        </div>
      <% end %>
      <label class="flex items-center mt-3">
        <%= radio_button(d, :is_enabled, false, class: "w-5 h-5 mr-2 radio") %>
        Do not charge for downloads
      </label>
    </div>
    """
  end

  def current(%{source: changeset}), do: current(changeset)
  def current(changeset), do: Ecto.Changeset.apply_changes(changeset)

  def is_package_description_length_long?(nil), do: false
  def is_package_description_length_long?(description), do: byte_size(description) > 100

  defp download_price(form),
    do: form |> current() |> Map.get(:download_each_price, Money.new(5000))
end
