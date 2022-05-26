defmodule PicselloWeb.BookingProposalLive.Shared do
  @moduledoc false
  use Phoenix.Component
  import PicselloWeb.LiveHelpers, only: [strftime: 3, testid: 1, badge: 1, shoot_location: 1]
  import PicselloWeb.Gettext, only: [dyn_gettext: 1, ngettext: 3]
  alias Picsello.{Job, Package, Packages}

  def banner(assigns) do
    ~H"""
    <%= if assigns[:read_only] do %>
      <.badge color={:gray} mode={:outlined}>Read-only</.badge>
    <% end %>

    <h1 class="mb-4 text-3xl font-bold"><%= @title %></h1>

    <div class="py-4 bg-base-200 modal-banner">
      <div class="text-2xl font-bold">
        <h2><%= Job.name @job %> Shoot <%= if @package, do: @package.name %></h2>
      </div>

      <%= render_slot @inner_block%>
    </div>
    """
  end

  def total(assigns) do
    ~H"""
    <div class="contents">
      <%= with discount_percent when discount_percent != nil <- Packages.discount_percent(@package) do %>
        <dl class="flex justify-between">
          <dt>Session fee</dt>
          <dd><%= Package.base_price(@package) %></dd>
        </dl>
        <dl class="flex justify-between text-green-finances-300 my-2">
          <dt>Discount</dt>
          <dd><%= discount_percent %>%</dd>
        </dl>
      <% end %>
      <dl class="flex justify-between text-xl font-bold">
        <dt>Total</dt>
        <dd><%= Package.price(@package) %></dd>
      </dl>

    </div>
    """
  end

  def items(assigns) do
    assigns = Enum.into(assigns, %{inner_block: nil})

    ~H"""
    <div class="mt-4 grid grid-cols-2 sm:grid-cols-[2fr,3fr] gap-4 sm:gap-6">
      <dl class="flex flex-col">
        <dt class="inline-block font-bold">Dated:</dt>
        <dd class="inline"><%= strftime(@photographer.time_zone, @proposal.inserted_at, "%b %d, %Y") %></dd>
      </dl>

      <dl class="flex flex-col">
        <dt class="inline-block font-bold">Quote #:</dt>
        <dd class="inline after:block"><%= @proposal.id |> Integer.to_string |> String.pad_leading(6, "0") %></dd>
      </dl>

      <hr class="col-span-2">

      <dl class="flex flex-col col-span-2 sm:col-span-1">
        <dt class="font-bold">For:</dt>
        <dd><%= @client.name %></dd>
        <dd class="inline"><%= @client.email %></dd>

        <dt class="mt-4 font-bold">Package:</dt>
        <dd><%= @package.name %></dd>
      </dl>

      <dl class="flex flex-col col-span-2 sm:col-span-1">
        <dt class="font-bold">From:</dt>
        <dd><%= @organization.name %></dd>
        <dt class="mt-4 font-bold">Email:</dt>
        <dd><%= @photographer.email %></dd>
      </dl>

      <div class="block pt-2 border-t col-span-2 sm:hidden">
        <.total package={@package} />
        <%= if @inner_block, do: render_slot @inner_block %>
      </div>

      <div class="modal-banner uppercase font-bold py-4 bg-base-200 grid grid-cols-[2fr,3fr] gap-4 col-span-2">
        <h2>item</h2>
        <h2 class="hidden sm:block">details</h2>
      </div>

      <%= for shoot <- @shoots do %>
        <div {testid("shoot-title")} class="flex flex-col col-span-2 sm:col-span-1">
          <h3 class="font-bold"><%= shoot.name %></h3>
          <%= strftime(@photographer.time_zone, shoot.starts_at, "%B %d, %Y") %>
        </div>

        <div {testid("shoot-description")} class="flex flex-col col-span-2 sm:col-span-1">
          <p>
            <%= dyn_gettext("duration-#{shoot.duration_minutes}") %>
            starting at <%= strftime(@photographer.time_zone, shoot.starts_at, "%-I:%M %P") %>
          </p>

          <p><%= shoot_location(shoot) %></p>
        </div>

        <hr class="col-span-2">
      <% end %>

      <div class="col-span-2 sm:col-span-1">
        <h3 class="font-bold">Photo Downloads</h3>
        <%= case Packages.Download.from_package(@package) do %>
          <% %{includes_credits: true} = d -> %>
            <p><%= ngettext "1 download credit", "%{count} download credits", d.count %> included</p>
            <p> Additional downloads @ <%= d.each_price %>/ea </p>
          <% %{is_enabled: true} = d -> %>
            <p> Download photos @ <%= d.each_price %>/ea </p>
          <% _ -> %>
            <p> All photos downloadable </p>
        <% end %>
      </div>

      <hr class="hidden col-span-2 sm:block">

      <div class="hidden col-start-2 sm:block">
        <.total package={@package} />
        <%= if @inner_block, do: render_slot @inner_block %>
      </div>
    </div>
    """
  end

  def package_description_length_long?(nil), do: false
  def package_description_length_long?(description), do: byte_size(description) > 100
end
