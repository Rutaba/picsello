defmodule PicselloWeb.BookingProposalLive.Shared do
  @moduledoc false
  use Phoenix.Component
  use Phoenix.HTML

  import PicselloWeb.LiveHelpers,
    only: [
      strftime: 3,
      testid: 1,
      badge: 1,
      shoot_location: 1,
      finish_booking: 1,
      stripe_checkout: 1,
      noreply: 1,
      icon: 1
    ]

  import PicselloWeb.ClientBookingEventLive.Shared,
    only: [
      blurred_thumbnail: 1
    ]

  import PicselloWeb.Gettext, only: [dyn_gettext: 1, ngettext: 3]

  alias Picsello.{Repo, PaymentSchedules, Notifiers, Job, Package, Packages}
  alias PicselloWeb.Router.Helpers, as: Routes

  def visual_banner(assigns) do
    assigns =
      Enum.into(assigns, %{
        proposal: nil
      })

    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 items-center gap-4 md:gap-10">
      <div>
        <%= if assigns[:read_only] do %>
          <.badge color={:gray} mode={:outlined}>Read-only</.badge>
        <% end %>

        <h1 class="text-3xl font-light">
          <%= @title %>
          <%= if @client do %>
            for <%= @client.name %>
          <% end %>
        </h1>

        <%= if @proposal && @proposal.accepted_at do %>
          <p class="text-base-250">Accepted on <%= strftime(@photographer.time_zone, @proposal.accepted_at, "%b %d, %Y") %></p>
        <% end %>

        <%= if @package do %>
          <%= if @job do %>
            <p class="mt-2 text-base-250"><%= Money.to_string(PaymentSchedules.total_price(@job), symbol: false, code: true) %></p>
          <% end %>
          <.photo_dowloads_display package={@package} class="text-base-250 mt-2" />
        <% end %>

        <%= if @package && @package.description do %>
          <hr class="my-4" />
          <div class="mt-2 mb-4" phx-hook="PackageDescription" id={"package-description-#{@package.id}"} data-event="click">
            <div class="line-clamp-2 raw_html raw_html_inline mb-4 text-base-250">
              <%= raw @package.description %>
            </div>
            <%= if package_description_length_long?(@package.description) do %>
              <button class="flex items-center font-light text-base-250 view_more_click" type="button">
                <span>See more</span> <.icon name="down" class="text-base-250 h-4 w-4 stroke-current stroke-2 ml-1 transition-transform" />
              </button>
            <% end %>
          </div>
        <% end %>

      </div>

      <%= if @package && @package.thumbnail_url do %>
        <div>
          <.blurred_thumbnail class="w-full" url={@package.thumbnail_url} />
        </div>
      <% end %>
    </div>
    """
  end

  def total(assigns) do
    discount =
      Money.subtract(
        Package.price_before_discounts(assigns.package),
        Package.price(assigns.package)
      )

    assigns =
      Enum.into(assigns, %{
        total_heading: "Total",
        discount: discount
      })

    ~H"""
    <div class="contents">
      <%= with discount_percent when discount_percent != nil <- Packages.discount_percent(@package) do %>
        <dl class="flex justify-between">
          <dt>Session fee</dt>
          <dd><%= Money.to_string(Package.price_before_discounts(@package), symbol: false, code: true)%></dd>
        </dl>
        <dl class="flex justify-between text-green-finances-300 my-2">
          <dt>Discount</dt>
          <dd><%= Money.to_string(@discount, symbol: false, code: true) %></dd>
        </dl>
      <% end %>
      <dl class="flex justify-between text-xl font-light mt-4">
        <dt>
          <%= if (@total_heading) do %>
            <%= @total_heading %>
          <% else %>
            Total
          <%end%>
        </dt>
        <dd class="bold"><%= Money.to_string(Package.price(@package), symbol: false, code: true)%></dd>
      </dl>

    </div>
    """
  end

  def items(%{package: package} = assigns) do
    assigns =
      Enum.into(assigns, %{
        inner_block: nil,
        print_credit: get_print_credit(package),
        show_header: true,
        total_heading: nil
      })

    ~H"""
    <div class="mt-4 grid grid-cols-2 sm:grid-cols-[2fr,2fr] gap-4 sm:gap-6">
      <%= if @show_header do %>
        <dl class="flex flex-col">
          <dt class="inline-block font-light">Dated:</dt>
          <dd class="inline"><%= strftime(@photographer.time_zone, @proposal.inserted_at, "%b %d, %Y") %></dd>
        </dl>

        <dl class="flex flex-col">
          <dt class="inline-block font-light">Order #:</dt>
          <dl class="flex justify-between">
            <dd class="inline after:block"><%= @proposal.id |> Integer.to_string |> String.pad_leading(6, "0") %></dd>
            <%= link to: Routes.job_download_path(@socket, :download_invoice_pdf, @proposal.job_id, @proposal.id) do %>
              <dd class="inline link text-black">Download Invoice</dd>
            <% end %>
          </dl>
        </dl>

        <hr class="col-span-2">

        <dl class="flex flex-col col-span-2 sm:col-span-1">
          <dt class="font-light">For:</dt>
          <dd><%= @client.name %></dd>
          <dd class="inline"><%= @client.email %></dd>
        </dl>

        <dl class="flex flex-col col-span-2 sm:col-span-1">
          <dt class="font-light">From:</dt>
          <dd><%= @organization.name %></dd>
          <dt class="mt-4 font-light">Email:</dt>
          <dd><%= @photographer.email %></dd>
        </dl>
      <% end %>

      <div class="block pt-2 border-t col-span-2 sm:hidden">
        <.total package={@package} total_heading={@total_heading} />
        <%= if @inner_block, do: render_slot @inner_block %>
      </div>

      <div class="modal-banner uppercase font-light py-2 bg-base-200 grid grid-cols-[2fr,2fr] gap-4 col-span-2">
        <h2>Item</h2>
        <h2>Details</h2>
      </div>

      <%= if @shoots do %>
        <%= for shoot <- @shoots do %>
          <div {testid("shoot-title")} class="flex flex-col col-span-1 sm:col-span-1 pl-4 md:pl-8">
            <h3 class="font-light"><%= shoot.name %></h3>
            <%= strftime(@photographer.time_zone, shoot.starts_at, "%B %d, %Y") %>
          </div>

          <div {testid("shoot-description")} class="flex flex-col col-span-1 sm:col-span-1">
            <p>
              <%= dyn_gettext("duration-#{shoot.duration_minutes}") %>
              starting at <%= strftime(@photographer.time_zone, shoot.starts_at, "%-I:%M %P") %>
            </p>
            <p><%= shoot_location(shoot) %></p>
          </div>

          <hr class="col-span-2">
        <% end %>
      <% end %>

      <div class="flex flex-col col-span-1 sm:col-span-1 pl-4 md:pl-8">
        <h3 class="font-light">Photo Downloads</h3>
      </div>

      <div class="flex flex-col col-span-1 sm:col-span-1">
        <.photo_dowloads_display package={@package} />
      </div>

      <%= if @print_credit do %>
        <hr class="col-span-2">
        <div class="flex flex-col col-span-1 sm:col-span-1">
          <h3 class="font-light">Print Credits</h3>
        </div>

        <div class="flex flex-col col-span-1 sm:col-span-1">
          <p><%= get_amount(@print_credit) %><%= @print_credit.currency%> in print credits to use in your gallery</p>
        </div>
      <% end %>

      <hr class="hidden col-span-2 sm:block">

      <div class="hidden col-start-2 col-span-1 sm:block pr-4 md:pr-8">
        <.total package={@package} total_heading={@total_heading} />
        <%= if @inner_block, do: render_slot @inner_block %>
      </div>
    </div>
    """
  end

  def date_display(assigns) do
    ~H"""
      <div class="flex items-center">
        <.icon name="calendar" class="w-5 h-5 text-black" />
        <span class="ml-2 pt-1 text-base-250"><%= @date %></span>
      </div>
    """
  end

  def address_display(assigns) do
    ~H"""
      <div class={"flex items-center #{@class}"}>
        <.icon name="pin" class="w-5 h-5 text-black" />
        <span class="ml-2 pt-1"><%= @address %></span>
      </div>
    """
  end

  def photo_dowloads_display(assigns) do
    assigns =
      Enum.into(assigns, %{
        class: ""
      })

    ~H"""
    <div class={"#{@class}"}>
      <%= case Packages.Download.from_package(@package) do %>
        <% %{status: :limited} = d -> %>
          <p><%= ngettext "1 photo download", "%{count} photo downloads", d.count %></p>
          <p> Additional downloads @ <%= Money.to_string(d.each_price, symbol: false, code: true)%>/ea </p>
        <% %{status: :none} = d -> %>
          <p> Download photos @ <%= Money.to_string(d.each_price, symbol: false, code: true)%>/ea </p>
        <% _ -> %>
          <p> All photos downloadable </p>
      <% end %>
    </div>
    """
  end

  def questionnaire_item(assigns) do
    ~H"""
    <dt class="pt-4">
      <label class="input-label" for={"question_#{@question_index}"}>
        <%= @question.prompt %>
      </label>
      <%= if @question.optional do %>
        <em class="text-xs">(optional)</em>
      <% end %>
    </dt>
      <%= case @question.type do %>
        <% :multiselect -> %>
          <input type="hidden" name={"answers[#{@question_index}][]"} value="">

          <dd>
            <%= for {option, option_index} <- @question.options |> Enum.with_index() do %>
              <label class="flex items-center mt-2">
                <input
                  class="checkbox"
                  type="checkbox"
                  name={"answers[#{@question_index}][]"}
                  value={option_index}
                  checked={@answer |> Enum.map(&String.to_integer(&1)) |> Enum.member?(option_index)}>
                  <div class="pl-2 input-label" ><%= option %></div>
              </label>
            <% end %>
          </dd>

        <% :select -> %>
          <dd>
            <%= for {option, option_index} <- @question.options |> Enum.with_index() do %>
              <label class="flex items-center mt-2">
                <input
                  class="radio"
                  type="radio"
                  name={"answers[#{@question_index}][]"}
                  value={option_index}
                  checked={@answer |> Enum.map(&String.to_integer(&1)) |> Enum.member?(option_index)}>
                <div class="pl-2 input-label" ><%= option %></div>
              </label>
            <% end %>
          </dd>

        <% :text -> %>
          <dd class="mt-2">
            <input type="text" phx-debounce="1000" class="w-full text-input" id={"question_#{@question_index}"} name={"answers[#{@question_index}][]"} value={@answer} placeholder={@question.placeholder} />
          </dd>

        <% :phone -> %>
          <dd class="mt-2">
            <input type="tel" phx-debounce="1000" class="w-full text-input" id={"question_#{@question_index}"} name={"answers[#{@question_index}][]"} value={@answer} />
          </dd>

        <% :email -> %>
          <dd class="mt-2">
            <input type="email" phx-debounce="1000" class="w-full text-input" id={"question_#{@question_index}"} name={"answers[#{@question_index}][]"} value={@answer} />
          </dd>

        <% :date -> %>
          <dd class="mt-2">
            <input type="date" phx-debounce="1000" class="w-full text-input" id={"question_#{@question_index}"} name={"answers[#{@question_index}][]"} value={@answer} />
          </dd>

        <% :textarea -> %>
          <dd class="mt-2">
            <textarea phx-debounce="1000" class="w-full text-input"  id={"question_#{@question_index}"} name={"answers[#{@question_index}][]"}><%= @answer %></textarea>
          </dd>
      <% end %>
    """
  end

  def get_amount(nil), do: nil

  def get_amount(print_credit) do
    num = print_credit.amount
    decimal_places = 2
    integer_length = (num / 100.0) |> round() |> to_string() |> String.length()
    total_length = integer_length + decimal_places + 1

    (num / 100.0)
    |> Float.round(decimal_places)
    |> Float.to_string()
    |> String.replace(",", "")
    |> String.pad_trailing(total_length, "0")
  end

  def get_print_credit(%{print_credits: print_credit}) do
    if Money.zero?(print_credit) do
      nil
    else
      print_credit
    end
  end

  def handle_checkout(socket, job) do
    if PaymentSchedules.free?(job) do
      finish_booking(socket) |> noreply()
    else
      stripe_checkout(socket) |> noreply()
    end
  end

  def handle_offline_checkout(socket, job, proposal) do
    if PaymentSchedules.free?(job) do
      finish_booking(socket) |> noreply()
    else
      job
      |> PaymentSchedules.next_due_payment()
      |> case do
        nil -> raise("There is no unpaid payment schedule found against #{job.id}")
        payment_schedule -> payment_schedule
      end
      |> Ecto.Changeset.change(%{is_with_cash: true, type: "cash"})
      |> Repo.update!()

      Notifiers.ClientNotifier.deliver_payment_due(proposal)
      Notifiers.ClientNotifier.deliver_paying_by_invoice(proposal)
      Notifiers.UserNotifier.deliver_paying_by_invoice(proposal)

      send(self(), {:update_offline_payment_schedules})

      socket
      |> noreply()
    end
  end

  def formatted_date(%Job{shoots: [shoot | _]}, photographer) do
    strftime(photographer.time_zone, shoot.starts_at, "%A, %B %-d @ %-I:%M %P")
  end

  def package_description_length_long?(nil), do: false
  def package_description_length_long?(description), do: byte_size(description) > 100
end
