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
          <div class="hidden p-4 text-sm rounded bg-white font-sans shadow my-4 w-full absolute top-2 z-[15]" data-offset="0" role="tooltip">
            <div class="line-clamp-6 raw_html"></div>
            <button class="inline-block text-blue-planning-300">View all</button>
          </div>
          <%= if package_description_length_long?(@package.description) do %>
            <button class="inline-block text-blue-planning-300 view_more">View more</button>
          <% end %>
        </div>

        <dl class="flex flex-row-reverse items-center justify-end mt-auto">
          <.digital_detail id="package_detail" download_each_price={@package.download_each_price} download_count={@package.download_count}/>
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

  def print_credit_fields(assigns) do
    ~H"""
    <div class="border border-solid mt-6 p-6 rounded-lg">
      <% p = form_for(@package_pricing, "#") %>
      <.print_fields_heading />

      <div class="mt-4 font-normal text-base leading-6">
        <div class="mt-2">
          <label class="flex items-center font-bold">
            <%= radio_button(p, :is_enabled, true, class: "w-5 h-5 mr-2.5 radio") %>
            Gallery includes Print Credits
          </label>
          <div class="flex items-center gap-4 ml-7">
            <%= if p |> current() |> Map.get(:is_enabled) do %>
              <%= input(@f, :print_credits, placeholder: "$0.00", class: "mt-2 w-full sm:w-32 text-lg text-center font-normal", phx_hook: "PriceMask") %>
              <div class="flex items-center text-base-250">
                <%= label_for @f, :print_credits, label: "as a portion of Package Price", class: "font-normal" %>
              </div>
            <% end %>
          </div>
        </div>

        <label class="flex items-center mt-3 font-bold">
          <%= radio_button(p, :is_enabled, false, class: "w-5 h-5 mr-2.5 radio") %>
          Gallery does not include Print Credits
        </label>
      </div>
    </div>
    """
  end

  # digital download fields for package & pricing
  def digital_download_fields(assigns) do
    assigns = Map.put_new(assigns, :for, nil)

    ~H"""
      <div class="border border-solid mt-6 p-6 rounded-lg">
        <% d = form_for(@download, "#") %>
        <.download_fields_heading title="Digital Collection" d={d} for={@for}>
          <p class="text-base-250">High-Resolution Digital Images available via download.</p>
        </.download_fields_heading>

        <.build_download_fields download_changeset={d} {assigns} />
      </div>
    """
  end

  defp download_fields_heading(%{d: d} = assigns) do
    ~H"""
    <div class="mt-9 md:mt-1" {testid("download")}>
      <h2 class="mb-2 text-xl font-bold justify-self-start sm:mr-4 whitespace-nowrap"><%= @title %></h2>
      <%= if @for == :create_gallery || (get_field(d, :status) == :limited) do %>
        <%= render_slot(@inner_block) %>
      <% end %>
    </div>
    """
  end

  defp build_download_fields(%{for: key, download_changeset: download_changeset} = assigns) do
    ~H"""
    <div class="flex flex-col md:flex-row w-full mt-3">
      <div class="flex flex-col ">
        <label class="flex items-center font-bold">
          <%= radio_button(download_changeset, :status, :limited, class: "w-5 h-5 mr-2 radio") %>
          <p><%= package_or_gallery_content(@for) %> includes a specified number of Digital Images <span class="font-normal italic text-base-250">(Charge for Digital Images)</span></p>
        </label>

        <%= if get_field(download_changeset, :status) == :limited do %>
            <div class="flex flex-col mt-1">
              <div class="flex flex-row items-center">
                <%= input(
                  download_changeset, :count, type: :number_input, phx_debounce: 200, step: 1,
                  min: 0, value: 0, class: "mt-3 w-full sm:w-32 text-lg text-center md:ml-7"
                ) %>
                <span class="ml-2 text-base-250">included</span>
              </div>
            </div>
        <% end %>

        <label class="flex items-center mt-3 font-bold">
            <%= radio_button(download_changeset, :status, :none, class: "w-5 h-5 mr-2 radio") %>
            <p><%= package_or_gallery_content(@for) %> does not include any Digital Images </p>
        </label>

        <label class="flex items-center mt-3 font-bold">
          <%= radio_button(download_changeset, :status, :unlimited, class: "w-5 h-5 mr-2 radio") %>
          <p><%= package_or_gallery_content(@for) %> includes Unlimited Digital Images <span class="font-normal italic text-base-250">(Do not charge for any Digital Image)</span></p>
        </label>

        <%= if @for == :create_gallery do %>
          <span class="italic ml-7">(Do not charge for any Digital Image)</span>
        <% end %>
      </div>
      <div class="my-8 border-t lg:my-0 lg:mx-8 lg:border-t-0 lg:border-l border-base-200"></div>
      <%= if get_field(download_changeset, :status) == :limited do %>
        <div class="ml-7 mt-3">
          <h3 class="font-bold">Upsell options</h3>
          <p class="mb-3 text-base-250">For additional Digital Images beyond what’s included in the <%= package_or_gallery_content(key) |> String.downcase() %> Digital Images are automatically set at <%= input_value(download_changeset, :each_price)%>/each.</p>
          <.include_download_price download_changeset={download_changeset} />
          <.is_buy_all download_changeset={download_changeset} />
        </div>
      <% end %>
    </div>
    """
  end

  defp is_buy_all(%{download_changeset: download_changeset} = assigns) do
    ~H"""
    <label class="flex items-center mt-3 font-bold">
      <%= checkbox(download_changeset, :is_buy_all, class: "w-5 h-5 mr-2.5 checkbox") %>
      <span>Set a <em>Buy Them All</em> price</span>
    </label>

    <%= if check?(download_changeset, :is_buy_all) do %>
      <div class="flex flex-row items-center mt-3 md:ml-7">
          <%= input(download_changeset, :buy_all, value: "$750.00", class: "w-full sm:w-32 text-lg text-center", phx_hook: "PriceMask") %>
          <%= error_tag download_changeset, :buy_all, class: "text-red-sales-300 text-sm ml-2" %>
          <span class="ml-3 text-base-250"> for all images </span>
      </div>
    <% end %>
    """
  end

  defp include_download_price(%{download_changeset: download_changeset} = assigns) do
    ~H"""
    <div class="flex flex-col justify-between mt-3 sm:flex-row ">
      <div class="w-full sm:w-auto">
        <label class="flex font-bold items-center">
          <%= checkbox(download_changeset, :is_custom_price, class: "w-5 h-5 mr-2.5 checkbox") %>
          <span>Set my own <em>per Digital Image</em> price</span>
        </label>
        <%= if check?(download_changeset, :is_custom_price) do %>
          <div class="flex flex-row items-center mt-3 ml-7 mt-3">
            <%= input(download_changeset, :each_price, class: "w-full sm:w-32 text-lg text-center", phx_hook: "PriceMask") %>
            <%= error_tag download_changeset, :each_price, class: "text-red-sales-300 text-sm ml-2" %>
            <span class="ml-3 text-base-250"> per image </span>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp print_fields_heading(assigns) do
    ~H"""
    <div class="mt-9 md:mt-1" {testid("print")}>
      <h2 class="mb-2 text-xl font-bold justify-self-start sm:mr-4 whitespace-nowrap">Professional Print Credit</h2>
      <p class="text-base-250">Print Credits allow your clients to order professional prints and products from your gallery.</p>
    </div>
    """
  end

  defp check?(d, field), do: d |> current() |> Map.get(field)
  defp get_field(d, field), do: d |> current() |> Map.get(field)

  def current(%{source: changeset}), do: current(changeset)
  def current(changeset), do: Ecto.Changeset.apply_changes(changeset)

  def package_description_length_long?(nil), do: false
  def package_description_length_long?(description), do: byte_size(description) > 100

  defp digital_detail(assigns) do
    ~H"""
        <%= cond do %>
        <%= Money.zero?(@download_each_price) -> %>
        <dt class="text-gray-500">All digital images included</dt>
        <% @download_count == 0 -> %>
        <dt class="text-gray-500">No digital images included</dt>
        <% true -> %>
        <dt class="text-gray-500">Digital images included</dt>
        <dd class="flex items-center justify-center w-8 h-8 mr-2 text-xs font-bold bg-gray-200 rounded-full group-hover:bg-white">
        <%= @download_count %>
        </dd>
      <% end %>
    """
  end

  defp package_or_gallery_content(key) do
    if key == :create_gallery do
      "Gallery"
    else
      "Package"
    end
  end
end
