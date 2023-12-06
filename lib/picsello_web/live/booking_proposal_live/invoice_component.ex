defmodule PicselloWeb.BookingProposalLive.InvoiceComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{PaymentSchedules, BookingProposal, EmailAutomations}
  import Picsello.EmailAutomationSchedules, only: [insert_job_emails: 5]
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
              <button {testid("pay-online")} type="submit" class="btn-tertiary flex gap-10 text-left" phx-disabled-with="Pay with card">
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
  def handle_event(
        "submit",
        %{},
        %{assigns: %{job: job, proposal: proposal, organization: organization}} = socket
      ) do
    handle_checkout(socket, job)
    insert_job_emails(job.type, organization.id, job.id, :job, [])
    # send thanks booking or thanks job when proposal accepts of zero package or pay with stripe
    send_thanks_email(proposal)
    socket |> noreply()
  end

  def handle_event(
        "pay_offline",
        %{},
        %{assigns: %{job: job, proposal: proposal, organization: organization}} = socket
      ) do
    insert_job_emails(job.type, organization.id, job.id, :job, [])
    # send thanks booking or thanks job when proposal selects Pay with cash/check
    send_thanks_email(proposal)
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

  defp send_thanks_email(proposal) do
    proposal = BookingProposal.preloads(proposal)
    # TODO: Remove this commented code later
    # state = if is_nil(proposal.job.booking_event), do: :thanks_job, else: :thanks_booking
    EmailAutomations.send_schedule_email(proposal.job, :thanks_booking)
  end
end
