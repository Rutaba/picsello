defmodule PicselloWeb.BookingProposalLive.InvoiceComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Repo, PaymentSchedules, Notifiers, BookingProposal}
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]

  import PicselloWeb.BookingProposalLive.Shared,
    only: [
      items: 1
    ]

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <form action="#" phx-submit="submit" phx-target={ @myself }>
        <.close_x />

        <h1 class="mb-4 text-3xl font-normal">Invoice for <%= @job.client.name %></h1>

        <.items {assigns}>
          <hr class="my-4" />

          <%= if @package.collected_price do %>
            <dl class={"flex justify-between"}>
              <dt>Previously collected</dt>
              <dd><%= @package.collected_price %></dd>
            </dl>
          <% end %>
          <%= unless PaymentSchedules.free?(@job) do %>
          <%= for payment <- @job.payment_schedules do %>
          <div class="bg-base-200 py-3 px-2">
              <dl class={classes("flex justify-between font-semibold", %{"text-black" => PaymentSchedules.paid?(payment), "font-bold" => payment == PaymentSchedules.unpaid_payment(@job)})}>
                <%= if PaymentSchedules.paid?(payment) do %>
                  <dt><%= payment.description %> paid on <%= strftime(@photographer.time_zone, payment.paid_at, "%b %d, %Y") %></dt>
                <% else %>
                  <dt><%= payment.description %> <%= if PaymentSchedules.past_due?(payment), do: "due today", else: "due on #{strftime(@photographer.time_zone, payment.due_at, "%b %d, %Y")}" %></dt>
                <% end %>
                <dd><%= payment.price %></dd>
                </dl>
          </div>
            <% end %>
          <% end %>
        </.items>

        <.footer>
          <%= cond do %>
            <% @read_only -> %>
            <% PaymentSchedules.free?(@job) -> %>
              <button type="submit" class="btn-primary" phx-disabled-with="Finish booking">
                Finish booking
              </button>
            <% !PaymentSchedules.free?(@job) -> %>
              <button type="submit" class="btn-primary" style="background-color: black; color: white;" phx-disabled-with="Pay with card">
                Pay with card  <br /> Fast easy and secure
              </button>
              <%= if(@organization.user.allow_cash_payment) do %>
              <button class="btn-primary" phx-click="pay_offline" phx-target={@myself} type="button">
                Pay with cash/check <br /> We will send you an invoice
              </button>
              <% end %>
          <% end %>
              <button class="btn-secondary" phx-click="modal" phx-value-action="close" type="button">
                Close
              </button>
        </.footer>
      </form>
    </div>
    """
  end

  @impl true
  def handle_event("submit", %{}, %{assigns: %{job: job}} = socket) do
    if PaymentSchedules.free?(job) do
      finish_booking(socket) |> noreply()
    else
      stripe_checkout(socket) |> noreply()
    end
  end

  def handle_event("pay_offline", %{}, %{assigns: %{job: job, proposal: proposal}} = socket) do
    if PaymentSchedules.free?(job) do
      finish_booking(socket) |> noreply()
    else
      proposal.job.payment_schedules
      |> Enum.each(&(&1 |> Ecto.Changeset.change(%{is_with_cash: true}) |> Repo.update!()))

      Notifiers.ClientNotifier.deliver_payment_due(proposal)
      Notifiers.ClientNotifier.deliver_paying_by_invoice(proposal)
      Notifiers.UserNotifier.deliver_paying_by_invoice(proposal)
      socket |> close_modal() |> noreply()
    end
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
      job: job,
      proposal: proposal,
      photographer: photographer,
      organization: organization,
      client: client,
      shoots: shoots,
      package: package
    })
  end
end
