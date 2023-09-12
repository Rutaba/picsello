defmodule PicselloWeb.BookingProposalLive.InvoiceComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{PaymentSchedules, BookingProposal}
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]

  import PicselloWeb.BookingProposalLive.Shared,
    only: [
      items: 1,
      handle_checkout: 2,
      handle_offline_checkout: 3
    ]

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <form action="#" phx-submit="submit" phx-target={ @myself }>
        <.close_x />

        <div class="mb-4 md:mb-8">
          <.maybe_show_photographer_logo? organization={@organization} />
        </div>

        <h1 class="mb-4 text-3xl font-light">Invoice for <%= @job.client.name %></h1>

        <.items {assigns} total_heading="Invoice Total">
          <hr class="my-4" />

          <%= if @package.collected_price do %>
            <dl class={"flex justify-between"}>
              <dt>Previously collected</dt>
              <dd><%= Money.to_string(@package.collected_price, symbol: false, code: true)%></dd>
            </dl>
          <% end %>
          <%= unless PaymentSchedules.free?(@job) do %>
            <div class="bg-base-200 py-3 px-4">
              <div class="text-xl flex justify-between">
                <h4>Paid</h4>
                <p><%= Money.to_string(PaymentSchedules.paid_price(@job), symbol: false, code: true) %></p>
              </div>
              <div class="text-xl flex justify-between mt-3">
                <h4>Owed</h4>
                <p><%=  Money.to_string(PaymentSchedules.owed_price(@job), symbol: false, code: true) %></p>
              </div>
            </div>
          <% end %>
        </.items>

        <.footer>
          <%= cond do %>
            <% @read_only -> %>
            <% PaymentSchedules.free?(@job) -> %>
              <button type="submit" class="btn-tertiary" phx-disabled-with="Finish booking">
                Finish booking
              </button>
            <% !PaymentSchedules.free?(@job) -> %>
              <button type="submit" class="btn-tertiary flex gap-10 text-left" phx-disabled-with="Pay with card">
                <span class="flex flex-col">
                  <strong>Pay online</strong> Fast, easy and secure
                </span>
                <span class="ml-auto">
                  <.icon name="forth" class="stroke-2 stroke-current h-4 w-4 mt-2" />
                </span>
              </button>
              <%= if(@organization.payment_options.allow_cash) do %>
                <button class="btn-secondary flex gap-10 text-left" phx-click="pay_offline" phx-target={@myself} type="button">
                  <span class="flex flex-col">
                    <strong>Pay with cash/check</strong> We'll send an invoice
                  </span>
                  <span class="ml-auto">
                    <.icon name="forth" class="stroke-2 stroke-current h-4 w-4 mt-2" />
                  </span>
                </button>
              <% end %>
          <% end %>
        </.footer>
      </form>
    </div>
    """
  end

  @impl true
  def handle_event("submit", %{}, %{assigns: %{job: job}} = socket) do
    handle_checkout(socket, job)
  end

  def handle_event("pay_offline", %{}, %{assigns: %{job: job, proposal: proposal}} = socket) do
    handle_offline_checkout(socket, job, proposal)
  end

  def open_modal_from_proposal(socket, proposal, read_only \\ true) do
    %{
      job:
        %{
          client: client,
          shoots: shoots,
          package: %{organization: %{user: photographer} = organization} = package
        } = job
    } = BookingProposal.preloads(proposal)

    socket
    |> open_modal(__MODULE__, %{
      read_only: read_only || PaymentSchedules.all_paid?(job),
      job: Picsello.PaymentSchedules.set_payment_schedules_order(job),
      proposal: proposal,
      photographer: photographer,
      organization: organization,
      client: client,
      shoots: shoots,
      package: package
    })
  end

  def to_book(payment, time_zone) do
    to_book = String.split(payment.description, " ", trim: true) |> List.last()

    if to_book == "Book",
      do: "due to book",
      else: "due on #{strftime(time_zone, payment.due_at, "%b %d, %Y")}"
  end
end
