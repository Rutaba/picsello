defmodule PicselloWeb.JobLive.Shared.MarkPaidModal do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.{Repo, PaymentSchedule, PaymentSchedules, Job}

  require Ecto.Query

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> then(&assign(&1, changeset: build_changeset(&1)))
    |> assign(:add_payment_show, false)
    |> assign_payments()
    |> assign_job()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <h1 id="payment-modal" class="flex justify-between mb-4 text-3xl font-bold">
        Mark <%= action_name(@live_action, :plural) %> as paid

        <button id="close" phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
          <.icon name="close-x" class="w-3 h-3 stroke-current stroke-2 sm:stroke-1 sm:w-6 sm:h-6"/>
        </button>

      </h1>

      <div>
              <div class="flex items-center justify-start">
              <dl class="flex flex-col">
                <dd class="pr-32 font-bold">
                  Balance to collect
                  <button id="send-email-link" class="link block mt-2 text-xs" phx-click="open-compose" phx-target={@myself}>Send reminder email</button>
                </dd>
              </dl>
              <h1 id="amount" class="rounded-lg bg-base-200 px-5 py-2"><%= PaymentSchedules.owed_offline_price(assigns.job) %></h1>
            </div>

        <table class="table-auto text-left w-full mt-8">
           <thead class="bg-base-200 h-11">
             <tr>
               <th id="job-name"><%= Job.name(@job) %></th>
               <th>Amount</th>
               <th>Type</th>
               <th>Status</th>
             </tr>
           </thead>
           <tbody>
           <%= @payment_schedules |> Enum.with_index |> Enum.map(fn({payment_schedules, index}) -> %>
             <tr>
               <td id="payments" class="font-bold font-sans">Payment <%= index + 1 %></td>
               <td id="offline-amount"><%= payment_schedules.price %></td>
               <td><%= payment_schedules.type %></td>
               <td class="text-green-finances-300">Paid <%= strftime(payment_schedules.paid_at.time_zone, payment_schedules.paid_at, "%b %d, %Y") %></td>
             </tr>
             <% end ) %>
           </tbody>
        </table>

        <hr class="my-4 sm:mt-8" />

        <%= if PaymentSchedules.owed_offline_price(assigns.job) |> Map.get(:amount) > 0 do %>
          <%= if !@add_payment_show do %>
            <.icon_button id="add-payment" class="border-solid border-2 border-blue-planning-300 rounded-md my-8 px-10 pb-1.5 flex items-center" title="Add a payment" color="blue-planning-300" icon="plus" phx-click="select_add_payment" phx-target={@myself}>
              Add a payment
            </.icon_button>
          <% end %>
        <% end %>


      <%= if @add_payment_show do %>
      <div class="rounded-lg border border-gray-300 mt-2">
      <h1 class="mb-4 rounded-t-lg bg-gray-300 px-5 text-2xl font-bold">Add a payment</h1>
      <.form id={"add-payment-form"} let={f} for={@changeset} phx-submit="save" phx-target={@myself} phx-change="validate">
        <div class="mx-5 grid grid-cols-3 gap-12">
          <dl>
            <dd>

            <%= labeled_input f, :price, placeholder: "$0.00", label: "Payment amount", class: "w-full px-4 text-lg mt-6 sm:mt-0 sm:font-normal font-bold text-center h-12", phx_hook: "PriceMask" %>

            </dd>
          </dl>

          <dl>

              <%= labeled_select f, :type,  ["Check": :check, "Cash": :cash], label: "Payment type", class: "w-full h-12 border rounded-lg" %>
          </dl>

          <dl>
            <dd>

            <%= labeled_input f, :paid_at, label: "Payment Date", type: :datetime_local_input, min: Date.utc_today(), time_zone: @current_user.time_zone, class: "w-full h-12" %>

            </dd>
          </dl>

          </div>
          <div class="flex justify-end items-center my-4 mr-5 gap-2">
            <button class="btn-primary button rounded-lg border border-blue-300 py-1 px-7 bg-white text-black hover:bg-base-200" type="button" title="cancel" phx-click="select_add_payment" phx-target={@myself} phx-value-action="close">Cancel</button>

            <button id="save-payment" class="btn-primary button rounded-lg border border-blue-300 py-1 px-7 bg-white text-black hover:bg-base-200" type="submit" phx-submit="save" disabled={!@changeset.valid?}>Save</button>
          </div>
        </.form>
    </div>
    <% end %>

        <div class="flex justify-end items-center mt-4 gap-8">
          <%= link to: Routes.job_download_path(@socket, :download_invoice_pdf, @proposal.job_id, @proposal.id) do %>
            <button class="link block leading-5 text-black text-base">Download invoice</button>
          <% end %>
          <button id="done" class="rounded-md bg-black px-8 py-3 text-white" phx-click="close-modal" phx-target={@myself}>Done</button>
        </div>

      </div>

    </div>
    """
  end

  def handle_event("close-modal", %{}, %{assigns: %{job: job}} = socket) do
    socket
    |> push_redirect(to: Routes.job_path(socket, :jobs, job.id))
    |> close_modal()
    |> noreply()
  end

  def handle_event(
        "validate",
        %{
          "payment_schedule" =>
            %{
              "paid_at" => _,
              "price" => _,
              "type" => _
            } = params
        },
        socket
      ) do
    socket = assign_changeset(socket, params)

    owed = PaymentSchedules.owed_offline_price(socket.assigns.job)

    price =
      Ecto.Changeset.get_field(socket.assigns.changeset, :price) ||
        %Money{amount: 0, currency: :USD}

    case Money.cmp(price, owed) do
      :gt ->
        socket.assigns.changeset
        |> Ecto.Changeset.add_error(:price, "must be within what remains")
        |> then(&assign(socket, :changeset, &1))

      _ ->
        socket
    end
    |> noreply()
  end

  @impl true
  def handle_event(
        "save",
        %{
          "payment_schedule" =>
            %{
              "paid_at" => _,
              "price" => _,
              "type" => _
            } = params
        },
        %{
          assigns: %{
            add_payment_show: add_payment_show,
            job: %{payment_schedules: payment_schedules} = job
          }
        } = socket
      ) do
    due_at = Enum.sort_by(payment_schedules, & &1.due_at, :asc) |> hd() |> Map.get(:due_at)

    params =
      Map.put(params, "due_at", due_at)
      |> Map.put("job_id", job.id)
      |> Map.put("description", "Offline Payment")

    case socket |> build_changeset(params) |> Repo.insert() do
      {:ok, _} ->
        socket
        |> assign(:add_payment_show, !add_payment_show)
        |> assign_payments()
        |> assign_job()
        |> noreply()

      _ ->
        socket |> put_flash(:error, "could not save payment_schedules.") |> noreply()
    end
  end

  def handle_event(
        "select_add_payment",
        _,
        %{
          assigns: %{
            add_payment_show: add_payment_show
          }
        } = socket
      ) do
    socket
    |> assign(:add_payment_show, !add_payment_show)
    |> noreply()
  end

  def handle_event("open-compose", %{}, socket), do: open_email_compose(socket)

  def handle_event("download-pdf", %{}, socket) do
    send(self(), :download_pdf)
    socket |> noreply()
  end

  def build_changeset(%{}, params \\ %{}) do
    PaymentSchedule.add_payment_changeset(params)
  end

  def assign_job(%{assigns: %{current_user: current_user, job: job}} = socket) do
    job =
      current_user
      |> Job.for_user()
      |> Job.not_leads()
      |> Ecto.Query.preload([:client, :package, :payment_schedules])
      |> Repo.get!(job.id)

    socket
    |> assign(:job, job)
  end

  def open(%{assigns: %{job: job, proposal: proposal}} = socket) do
    socket
    |> open_modal(__MODULE__, %{
      proposal: proposal,
      job: job,
      current_user: socket.assigns.current_user
    })
  end

  defp assign_payments(%{assigns: %{job: job}} = socket) do
    payment_schedules = PaymentSchedules.get_offline_payment_schedules(job.id)

    socket |> assign(:payment_schedules, payment_schedules)
  end

  defp assign_changeset(socket, params) do
    changeset =
      socket
      |> build_changeset(params)
      |> Map.put(:action, :validate)

    assign(socket, changeset: changeset)
  end

  defp open_email_compose(%{assigns: %{current_user: current_user}} = socket) do
    socket
    |> PicselloWeb.ClientMessageComponent.open(%{
      current_user: current_user,
      enable_size: true,
      enable_image: true
    })
    |> noreply()
  end
end