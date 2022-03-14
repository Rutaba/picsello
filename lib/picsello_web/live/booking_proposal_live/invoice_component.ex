defmodule PicselloWeb.BookingProposalLive.InvoiceComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{Repo, PaymentSchedules, BookingProposal, Job}
  import Phoenix.HTML, only: [raw: 1]
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.BookingProposalLive.Shared, only: [banner: 1, items: 1]
  require Logger

  @impl true
  def render(%{job: job} = assigns) do
    assigns =
      assigns
      |> Enum.into(%{
        deposit_paid: PaymentSchedules.deposit_paid?(job),
        remainder_paid: PaymentSchedules.remainder_paid?(job)
      })

    ~H"""
    <div class="modal">
      <form action="#" phx-submit="submit" phx-target={ @myself }>
        <.close_x />

        <.banner title="Invoice" job={@job} package={@package}>
          <p class="raw_html"><%= raw @package.description %></p>
        </.banner>

        <.items {assigns}>
          <hr class="my-4" />

          <dl class={classes("flex justify-between", %{"text-green-finances-300" => @deposit_paid, "font-bold" => !@deposit_paid})}>
            <%= if @deposit_paid do %>
              <dt>Retainer Paid on <%= strftime(@photographer.time_zone, PaymentSchedules.deposit_paid_at(@job), "%b %d, %Y") %></dt>
            <% else %>
              <dt>50% retainer today</dt>
            <% end %>
            <dd><%= PaymentSchedules.deposit_price(@job) %></dd>
          </dl>

          <dl class={classes("flex justify-between mt-4", %{"font-bold" => @deposit_paid && !@remainder_paid, "text-green-finances-300" => @remainder_paid})} >
            <%= if @remainder_paid do %>
              <dt>Remainder Paid on <%= strftime(@photographer.time_zone, PaymentSchedules.remainder_paid_at(@job), "%b %d, %Y") %></dt>
            <% else %>
              <dt>Remainder Due on <%= strftime(@photographer.time_zone, PaymentSchedules.remainder_due_on(@job), "%b %d, %Y") %></dt>
            <% end %>
            <dd><%= PaymentSchedules.remainder_price(@job) %></dd>
          </dl>
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
    {payment_type, payment} =
      if PaymentSchedules.deposit_paid?(job) do
        {:remainder, PaymentSchedules.remainder_payment(job)}
      else
        {:deposit, PaymentSchedules.deposit_payment(job)}
      end

    payment_type_desc =
      if payment_type == :deposit do
        :retainer
      else
        payment_type
      end

    line_items = [
      %{
        price_data: %{
          currency: "usd",
          product_data: %{
            name: "#{Job.name(job)} 50% #{payment_type_desc}"
          },
          unit_amount: payment.price.amount
        },
        quantity: 1
      }
    ]

    case payments().checkout_link(proposal, line_items,
           success_url:
             "#{BookingProposal.url(proposal.id, success: payment_type)}&session_id={CHECKOUT_SESSION_ID}",
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
      |> Repo.preload(job: [:client, :shoots, package: [organization: :user]])

    socket
    |> open_modal(__MODULE__, %{
      read_only: read_only || PaymentSchedules.remainder_paid?(job),
      job: job,
      proposal: proposal,
      photographer: photographer,
      organization: organization,
      client: client,
      shoots: shoots,
      package: package
    })
  end

  defp payments, do: Application.get_env(:picsello, :payments)
end
