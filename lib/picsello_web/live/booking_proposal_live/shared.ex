defmodule PicselloWeb.BookingProposalLive.Shared do
  @moduledoc false
  use Phoenix.Component
  use Phoenix.HTML

  import PicselloWeb.LiveHelpers, only: [strftime: 3, testid: 1, badge: 1, shoot_location: 1]
  import PicselloWeb.Gettext, only: [dyn_gettext: 1, ngettext: 3]

  alias Picsello.{Job, Package, Packages}
  alias PicselloWeb.Router.Helpers, as: Routes

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
      <dl class="flex justify-between text-xl font-bold mt-4">
        <dt>Total</dt>
        <dd><%= Package.price(@package) %></dd>
      </dl>

    </div>
    """
  end

  def items(%{package: package} = assigns) do
    assigns = Enum.into(assigns, %{inner_block: nil, print_credit: get_print_credit(package)})

    ~H"""
    <div class="mt-4 grid grid-cols-3 sm:grid-cols-[2fr,3fr] gap-4 sm:gap-6">
      <dl class="flex flex-col">
        <dt class="inline-block font-bold">Dated:</dt>
        <dd class="inline"><%= strftime(@photographer.time_zone, @proposal.inserted_at, "%b %d, %Y") %></dd>
      </dl>

      <dl class="flex flex-col">
        <dt class="inline-block font-bold">Order #:</dt>
        <dl class="flex justify-between">
          <dd class="inline after:block"><%= @proposal.id |> Integer.to_string |> String.pad_leading(6, "0") %></dd>
          <%= link to: Routes.job_download_path(@socket, :download_invoice_pdf, @proposal.job_id, @proposal.id) do %>
            <dd class="inline link text-black">Download Invoice</dd>
          <% end %>
        </dl>
      </dl>

      <hr class="col-span-2">

      <dl class="flex flex-col col-span-2 sm:col-span-1">
        <dt class="font-bold">For:</dt>
        <dd><%= @client.name %></dd>
        <dd class="inline"><%= @client.email %></dd>
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

      <div class="flex flex-col col-span-2 sm:col-span-1">
        <h3 class="font-bold">Photo Downloads</h3>
      </div>

      <div class="flex flex-col col-span-2 sm:col-span-1">
        <%= case Packages.Download.from_package(@package) do %>
          <% %{status: :limited} = d -> %>
            <p><%= ngettext "1 photo download", "%{count} photo downloads", d.count %></p>
            <p> Additional downloads @ <%= d.each_price %>/ea </p>
          <% %{status: :none} = d -> %>
            <p> Download photos @ <%= d.each_price %>/ea </p>
          <% _ -> %>
            <p> All photos downloadable </p>
          <% end %>
      </div>

      <%= if @print_credit do %>
        <hr class="col-span-2">
        <div class="flex flex-col col-span-2 sm:col-span-1">
          <h3 class="font-bold">Print Credits</h3>
        </div>

        <div class="flex flex-col col-span-2 sm:col-span-1">
          <p> $<%= @print_credit.amount / 100 |> Float.round(2)%> in print credits to use in your gallery</p>
        </div>
      <% end %>


      <hr class="hidden col-span-2 sm:block">

      <div class="hidden col-start-2 sm:block">
        <.total package={@package} />
        <%= if @inner_block, do: render_slot @inner_block %>
      </div>
    </div>
    """
  end

  def get_print_credit(%{print_credits: print_credit}) do
    if Money.zero?(print_credit) do
      nil
    else
      print_credit
    end
  end

  def package_description_length_long?(nil), do: false
  def package_description_length_long?(description), do: byte_size(description) > 100
end
