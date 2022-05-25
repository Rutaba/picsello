defmodule PicselloWeb.BookingProposalLive.InvoiceComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{Repo, PaymentSchedules, BookingProposal, Job}
  import Phoenix.HTML, only: [raw: 1]
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]

  import PicselloWeb.BookingProposalLive.Shared,
    only: [banner: 1, items: 1, is_package_description_length_long?: 1]

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <form action="#" phx-submit="submit" phx-target={ @myself }>
        <.close_x />

        <.banner title="Invoice" job={@job} package={@package}>
          <div class="mt-2 mb-4" phx-hook="PackageDescription" id={"package-description-#{@package.id}"} data-event="click">
            <div class="line-clamp-2 raw_html raw_html_inline mb-4">
              <%= raw @package.description %>
            </div>
            <%= if is_package_description_length_long?(@package.description) do %>
              <button class="flex items-center font-bold text-base-250 view_more_click" type="button"><.icon name="down" class="text-base-250 h-4 w-4 stroke-current stroke-2 mr-1 transition-transform" /> <span>See more</span></button>
            <% end %>
          </div>
        </.banner>

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
              <dl class={classes("flex justify-between", %{"text-green-finances-300" => PaymentSchedules.paid?(payment), "font-bold" => payment == PaymentSchedules.unpaid_payment(@job)})}>
                <%= if PaymentSchedules.paid?(payment) do %>
                  <dt><%= payment.description %> paid on <%= strftime(@photographer.time_zone, payment.paid_at, "%b %d, %Y") %></dt>
                <% else %>
                  <dt><%= payment.description %> <%= if PaymentSchedules.past_due?(payment), do: "due today", else: "due on #{strftime(@photographer.time_zone, payment.due_at, "%b %d, %Y")}" %></dt>
                <% end %>
                <dd><%= payment.price %></dd>
              </dl>
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
  def handle_event("submit", %{}, %{assigns: %{job: job}} = socket) do
    if PaymentSchedules.free?(job) do
      finish_booking(socket)
    else
      stripe_checkout(socket)
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

  defp stripe_checkout(%{assigns: %{proposal: proposal, job: job}} = socket) do
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

  def finish_booking(%{assigns: %{proposal: proposal}} = socket) do
    case PaymentSchedules.mark_as_paid(proposal, PicselloWeb.Helpers) do
      {:ok, _} ->
        send(self(), {:update_payment_schedules})
        socket |> noreply()

      {:error, _} ->
        socket |> put_flash(:error, "Couldn't finish booking") |> noreply()
    end
  end
end
