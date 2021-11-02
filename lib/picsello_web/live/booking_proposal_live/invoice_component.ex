defmodule PicselloWeb.BookingProposalLive.InvoiceComponent do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{Repo, BookingProposal, Package, Job}
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.BookingProposalLive.Shared, only: [banner: 1, items: 1]
  require Logger

  @impl true
  def render(%{proposal: proposal} = assigns) do
    assigns = assigns |> Enum.into(%{deposit_paid: BookingProposal.deposit_paid?(proposal)})

    ~H"""
    <div class="modal">
      <.close_x />

      <.banner title="Invoice" job={@job} package={@package}>
        <p><%= @package.description %></p>
      </.banner>

      <.items photographer={@photographer} proposal={@proposal} organization={@organization} shoots={@shoots} package={@package} client={@client}>
        <dl class="flex justify-between text-2xl font-bold">
          <dt>Total</dt>
          <dd><%= Package.price(@package) %></dd>
        </dl>

        <hr class="my-4" />

        <dl class={classes("flex justify-between", %{"text-green-finances-300" => @deposit_paid, "font-bold" => !@deposit_paid})}>
          <%= if @deposit_paid do %>
            <dt>Deposit Paid on <%= strftime(@photographer.time_zone, @proposal.deposit_paid_at, "%b %d, %Y") %></dt>
          <% else %>
            <dt>50% deposit today</dt>
          <% end %>
          <dd><%= Package.deposit_price(@package) %></dd>
        </dl>

        <dl class={classes("flex justify-between mt-4", %{"font-bold" => @deposit_paid})} >
          <dt>Remainder Due on <%= strftime(@photographer.time_zone, BookingProposal.remainder_due_on(@proposal), "%b %d, %Y") %></dt>
          <dd><%= Package.remainder_price(@package) %></dd>
        </dl>
      </.items>

      <.footer>
        <%= unless @read_only do %>
          <button class="btn-primary" phx-click="redirect-stripe" phx-target={@myself}>
            Pay Invoice
          </button>
        <% end %>

        <button class="btn-secondary" phx-click="modal" phx-value-action="close" type="button">Close</button>
      </.footer>
    </div>
    """
  end

  @impl true
  def handle_event("redirect-stripe", %{}, socket) do
    %{
      assigns: %{
        package: package,
        proposal: proposal,
        job: job
      }
    } = socket

    line_items = [
      %{
        price_data: %{
          currency: "usd",
          product_data: %{
            name: "#{Job.name(job)} 50% Deposit"
          },
          unit_amount:
            package
            |> Package.price()
            |> Money.multiply(0.5)
            |> then(& &1.amount)
        },
        quantity: 1
      }
    ]

    case payments().checkout_link(proposal, line_items,
           success_url: BookingProposal.url(proposal.id, success: true),
           cancel_url: BookingProposal.url(proposal.id)
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
      read_only: read_only,
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
