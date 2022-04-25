defmodule PicselloWeb.BookingProposalLive.InvoiceComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{Repo, PaymentSchedules, BookingProposal, Job}
  import Phoenix.HTML, only: [raw: 1]
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.BookingProposalLive.Shared, only: [banner: 1, items: 1]
  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <form action="#" phx-submit="submit" phx-target={ @myself }>
        <.close_x />

        <.banner title="Invoice" job={@job} package={@package}>
          <div class="line-clamp-2 raw_html"><%= raw @package.description %></div>
        </.banner>

        <.items {assigns}>
          <hr class="my-4" />

          <%= if @package.collected_price do %>
            <dl class={"flex justify-between"}>
              <dt>Previously collected</dt>
              <dd><%= @package.collected_price %></dd>
            </dl>
          <% end %>
          <%= for payment <- @job.payment_schedules do %>
            <dl class={classes("flex justify-between", %{"text-green-finances-300" => PaymentSchedules.paid?(payment), "font-bold" => payment == PaymentSchedules.unpaid_payment(@job)})}>
              <%= if PaymentSchedules.paid?(payment) do %>
                <dt><%= payment.description %> paid on <%= strftime(@photographer.time_zone, payment.paid_at, "%b %d, %Y") %></dt>
              <% else %>
                <dt><%= payment.description %> <%= if PaymentSchedules.past_due?(payment), do: "due today", else: "due on #{strftime(@photographer.time_zone, payment.due_at, "%b %d, %Y")}" %></dt>
              <% end %>
              <dd><%= payment.price %></dd>
            </dl>
          <% end %>
        </.items>

        <.footer>
          <%= unless @read_only do %>
            <button type="submit" class="btn-primary" phx-disabled-with="Pay Invoice">
              Pay Invoice
            </button>
          <% end %>

          <button class="btn-secondary" phx-click="modal" phx-value-action="close" type="button">Close</button>
        </.footer>
      </form>
    </div>
    """
  end

  @impl true
  def handle_event(
        "submit",
        %{},
        %{
          assigns: %{
            proposal: proposal,
            job: job
          }
        } = socket
      ) do
    payment = PaymentSchedules.unpaid_payment(job)

    line_items = [
      %{
        price_data: %{
          currency: "usd",
          unit_amount: payment.price.amount,
          product_data: %{
            name: "#{Job.name(job)} #{payment.description}",
            tax_code: Picsello.Payments.tax_code(:services)
          },
          tax_behavior: "exclusive"
        },
        quantity: 1
      }
    ]

    case PaymentSchedules.checkout_link(proposal, line_items,
           # manually interpolate here to not encode the brackets
           success_url: "#{BookingProposal.url(proposal.id)}?session_id={CHECKOUT_SESSION_ID}",
           cancel_url: BookingProposal.url(proposal.id),
           metadata: %{"paying_for" => payment.id}
         ) do
      {:ok, url} ->
        socket |> redirect(external: url) |> noreply()

      {:error, error} ->
        Logger.error(error)
        socket |> put_flash(:error, "Couldn't redirect to stripe. Please try again") |> noreply()
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
    } =
      proposal
      |> Repo.preload(
        [job: [:client, :shoots, :payment_schedules, package: [organization: :user]]],
        force: true
      )

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
