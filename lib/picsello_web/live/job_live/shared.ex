defmodule PicselloWeb.JobLive.Shared do
  @moduledoc """
  handlers used by both leads and jobs
  """
  alias Picsello.{
    Job,
    Shoot,
    ClientMessage,
    Repo,
    BookingProposal,
    Messages,
    Notifiers.ClientNotifier,
    Package,
    PaymentSchedules
  }

  alias PicselloWeb.Router.Helpers, as: Routes
  require Ecto.Query

  import Phoenix.LiveView
  import PicselloWeb.LiveHelpers
  import PicselloWeb.FormHelpers
  import Phoenix.HTML.Form
  import PicselloWeb.Gettext, only: [ngettext: 3]
  use Phoenix.Component

  def handle_event(
        "toggle-section",
        %{"section_id" => section_id},
        %{assigns: %{collapsed_sections: collapsed_sections}} = socket
      ) do
    collapsed_sections =
      if Enum.member?(collapsed_sections, section_id) do
        Enum.filter(collapsed_sections, &(&1 != section_id))
      else
        collapsed_sections ++ [section_id]
      end

    socket
    |> assign(:collapsed_sections, collapsed_sections)
    |> noreply()
  end

  def handle_event(
        "edit-shoot-details",
        %{"shoot-number" => shoot_number},
        %{assigns: %{shoots: shoots} = assigns} = socket
      ) do
    shoot_number = shoot_number |> String.to_integer()

    shoot = shoots |> Enum.into(%{}) |> Map.get(shoot_number)

    socket
    |> open_modal(
      PicselloWeb.ShootLive.EditComponent,
      assigns
      |> Map.take([:current_user, :job])
      |> Map.merge(%{
        shoot: shoot,
        shoot_number: shoot_number
      })
    )
    |> noreply()
  end

  def handle_event(
        "open-proposal",
        %{"action" => "" <> action},
        socket
      ) do
    socket
    |> PicselloWeb.BookingProposalLive.Show.open_page_modal(action, true)
    |> noreply()
  end

  def handle_event(
        "open-proposal",
        %{},
        %{assigns: %{proposal: %{id: proposal_id}}} = socket
      ),
      do: socket |> redirect(to: BookingProposal.path(proposal_id)) |> noreply()

  def handle_event(
        "open-notes",
        %{},
        socket
      ) do
    socket
    |> PicselloWeb.JobLive.Shared.NotesModal.open()
    |> noreply()
  end

  def handle_event("open-compose", %{}, socket), do: open_email_compose(socket)

  def handle_event("open-inbox", _, %{assigns: %{job: job}} = socket) do
    socket
    |> push_redirect(to: Routes.inbox_path(socket, :show, job.id))
    |> noreply()
  end

  def handle_info({:action_event, "open_email_compose"}, socket), do: open_email_compose(socket)

  def handle_info(
        {:message_composed, message_changeset},
        %{assigns: %{job: %{client: client} = job}} = socket
      ) do
    with {:ok, message} <- Messages.add_message_to_job(message_changeset, job),
         {:ok, _email} <- ClientNotifier.deliver_email(message, client.email) do
      socket
      |> PicselloWeb.ConfirmationComponent.open(%{
        title: "Email sent",
        subtitle: "Yay! Your email has been successfully sent"
      })
      |> noreply()
    else
      _error ->
        socket |> put_flash(:error, "Something went wrong") |> close_modal() |> noreply()
    end
  end

  def handle_info(
        {:update, %{shoot_number: shoot_number, shoot: new_shoot}},
        %{assigns: %{shoots: shoots, job: job}} = socket
      ) do
    socket
    |> assign(
      shoots: shoots |> Enum.into(%{}) |> Map.put(shoot_number, new_shoot) |> Map.to_list(),
      job: job |> Repo.preload(:shoots, force: true)
    )
    |> noreply()
  end

  def handle_info({:update, %{package: package}}, %{assigns: %{job: job}} = socket),
    do:
      socket
      |> assign(package: package, job: %{job | package: package, package_id: package.id})
      |> assign_shoots()
      |> noreply()

  def handle_info({:update, assigns}, socket),
    do: socket |> assign(assigns) |> noreply()

  def handle_info(
        {:inbound_messages, message},
        %{assigns: %{inbox_count: count, job: job}} = socket
      ) do
    count = if message.job_id == job.id, do: count + 1, else: count

    socket
    |> assign(:inbox_count, count)
    |> noreply()
  end

  def assign_shoots(
        %{assigns: %{package: %{shoot_count: shoot_count}, job: %{id: job_id}}} = socket
      ) do
    shoots = Shoot.for_job(job_id) |> Repo.all()

    socket
    |> assign(
      shoots:
        for(
          shoot_number <- 1..shoot_count,
          do: {shoot_number, Enum.at(shoots, shoot_number - 1)}
        )
    )
  end

  def assign_shoots(socket), do: socket |> assign(shoots: [])

  def assign_proposal(%{assigns: %{job: %{id: job_id}}} = socket) do
    proposal = BookingProposal.last_for_job(job_id) |> Repo.preload(:answer)
    socket |> assign(proposal: proposal)
  end

  defp assign_inbox_count(%{assigns: %{job: job}} = socket) do
    count =
      Job.by_id(job.id)
      |> ClientMessage.unread_messages()
      |> Repo.aggregate(:count)

    socket |> subscribe_inbound_messages() |> assign(:inbox_count, count)
  end

  defp subscribe_inbound_messages(%{assigns: %{current_user: current_user}} = socket) do
    Phoenix.PubSub.subscribe(
      Picsello.PubSub,
      "inbound_messages:#{current_user.organization_id}"
    )

    socket
  end

  @spec status_badge(%{job_status: %Picsello.JobStatus{}, class: binary}) ::
          %Phoenix.LiveView.Rendered{}
  def status_badge(%{job_status: %{current_status: status, is_lead: is_lead}} = assigns) do
    {label, color} = status_content(is_lead, status)

    assigns =
      assigns
      |> Enum.into(%{
        label: label,
        color: color,
        class: ""
      })

    ~H"""
      <.badge class={@class} color={@color}>
        <%= @label %>
      </.badge>
    """
  end

  def status_content(_, :archived), do: {"Archived", :gray}
  def status_content(_, :completed), do: {"Completed", :green}
  def status_content(false, _), do: {"Active", :blue}
  def status_content(true, :not_sent), do: {"Created", :blue}
  def status_content(true, :sent), do: {"Awaiting Acceptance", :blue}
  def status_content(true, :accepted), do: {"Awaiting Contract", :blue}

  def status_content(true, :signed_with_questionnaire),
    do: {"Awaiting Questionnaire", :blue}

  def status_content(true, status) when status in [:signed_without_questionnaire, :answered],
    do: {"Awaiting Payment", :blue}

  def status_content(_, status), do: {status |> Phoenix.Naming.humanize(), :blue}

  def title_header(assigns) do
    ~H"""
    <h1 class="flex items-center justify-between mt-4 text-4xl font-bold md:justify-start">
      <div class="flex items-center">
        <.live_link to={@back_path} class="rounded-full bg-base-200 flex items-center justify-center p-2.5 mt-2 mr-4">
          <.icon name="back" class="w-4 h-4 stroke-2"/>
        </.live_link>
        <%= Job.name @job %>
      </div>

      <button title="Manage" type="button" phx-click="manage" class="relative flex items-center justify-center pb-4 h-5 ml-4 mt-2 text-2xl font-bold leading-3 border rounded w-9 border-blue-planning-300 text-blue-planning-300">
        &hellip;
      </button>
    </h1>
    """
  end

  def section(assigns) do
    ~H"""
    <section class="sm:border sm:border-base-200 sm:rounded-lg mt-8 overflow-hidden">
      <div class="flex bg-base-200 px-4 py-3 items-center cursor-pointer" phx-click="toggle-section" phx-value-section_id={@id}>
        <div class="w-8 h-8 rounded-full bg-white flex items-center justify-center">
          <.icon name={@icon} class="w-5 h-5" />
        </div>
        <h2 class="text-2xl font-bold ml-3"><%= @title %></h2>
        <div class="ml-auto">
          <%= if Enum.member?(@collapsed_sections, @id) do %>
            <.icon name="down" class="w-5 h-5 stroke-current stroke-2" />
          <% else %>
            <.icon name="up" class="w-5 h-5 stroke-current stroke-2" />
          <% end %>
        </div>
      </div>
      <div class={classes("p-6", %{"hidden" => Enum.member?(@collapsed_sections, @id)})}>
        <%= render_slot @inner_block %>
      </div>
    </section>
    """
  end

  def card(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> "" end)
      |> assign_new(:color, fn -> "blue-planning-300" end)

    ~H"""
    <div {testid("card-#{@title}")} class={"flex overflow-hidden border border-base-200 rounded-lg #{@class}"}>
      <div class={"w-3 flex-shrink-0 border-r bg-#{@color}"} />
      <div class="flex flex-col w-full p-4">
        <h3 class={"mb-2 mr-4 text-xl font-bold text-#{@color}"}><%= @title %></h3>
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  def communications_card(assigns) do
    ~H"""
    <.card color="orange-inbox-300" title="Communications" class="md:col-span-2">
      <div {testid("inbox")} class="flex flex-col lg:flex-row">
        <div class="flex-1 text-base-250">
          Inbox
          <div class="flex border border-base-200 rounded-lg p-8 mt-4 justify-center">
            <span class={classes("w-7 h-7 flex items-center justify-center text-lg font-bold text-white rounded-full mr-2 pb-1", %{"bg-orange-inbox-300" => @inbox_count > 0,"bg-base-250" => @inbox_count <= 0})}>
              <%= @inbox_count %>
            </span>
            <span class={if @inbox_count > 0, do: "text-orange-inbox-300", else: "text-base-250"}>
              <%= ngettext "new message", "new messages", @inbox_count %>
            </span>
          </div>
          <div class="flex flex-col-reverse sm:flex-row justify-end mt-4">
            <button type="button" class="link mx-8 my-4" phx-click="open-inbox">
              Go to inbox
            </button>
            <button type="button" class="btn-primary px-8" phx-click="open-compose">
              Send message
            </button>
          </div>
        </div>
        <div class="my-8 border-t lg:my-0 lg:mx-8 lg:border-t-0 lg:border-l border-base-200"></div>
        <div class="flex flex-col flex-[0.5]">
          <span class="mb-1 font-bold"><%= @job.client.name %></span>
          <a href={"tel:#{@job.client.phone}"} class="flex items-center text-xs">
            <.icon name="phone" class="text-blue-planning-300 mr-2 w-4 h-4" />
            <span class="text-base-250"><%= @job.client.phone %></span>
          </a>
          <a href="#" phx-click="open-compose" class="flex items-center text-xs mt-2">
            <.icon name="envelope" class="text-blue-planning-300 mr-2 w-4 h-4" />
            <span class="text-base-250"><%= @job.client.email %></span>
          </a>
        </div>
      </div>
    </.card>
    """
  end

  def package_details_card(assigns) do
    ~H"""
    <.card title="Package details" class="h-52">
      <%= if @package do %>
        <p class="font-bold"><%= @package.name %></p>
        <p><%= @package |> Package.price() |> Money.to_string(fractional_unit: false) %></p>
        <%= if @package.download_count > 0 do %>
          <p><%= ngettext "%{count} image", "%{count} images", @package.download_count %></p>
        <% end %>
        <%= unless @package |> Package.print_credits() |> Money.zero?() do %>
          <p><%= "#{Money.to_string(@package.print_credits, fractional_unit: false)} print credit" %></p>
        <% end %>
        <%= if Job.lead?(@job) && !@proposal do %>
          <.icon_button color="blue-planning-300" icon="pencil" phx-click="edit-package" class="mt-auto self-end">
            Edit
          </.icon_button>
        <% end %>
      <% else %>
        <p class="text-base-250">Click edit to add a package. You can come back to this later if your client isn’t ready for pricing quite yet.</p>
        <.icon_button color="blue-planning-300" icon="pencil" phx-click="add-package" class="mt-auto self-end">
          Edit
        </.icon_button>
      <% end %>
    </.card>
    """
  end

  def private_notes_card(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> "" end)
      |> assign_new(:content_class, fn -> "line-clamp-4" end)

    ~H"""
    <.card title="Private notes" class={"h-52 #{@class}"}>
      <%= if @job.notes do %>
        <p class={"whitespace-pre-line #{@content_class}"}><%= @job.notes %></p>
      <% else %>
        <p class={"text-base-250 #{@content_class}"}>Click edit to add a note about your client and any details you want to remember.</p>
      <% end %>
      <.icon_button color="blue-planning-300" icon="pencil" phx-click="open-notes" class="mt-auto self-end">
        Edit
      </.icon_button>
    </.card>
    """
  end

  def shoot_details_section(assigns) do
    ~H"""
    <.section id="shoot-details" icon="camera-check" title="Shoot details" collapsed_sections={@collapsed_sections}>
      <%= if is_nil(@package) do %>
        <p>You don’t have any shoots yet! If your client has a date but hasn’t decided on pricing, add a placeholder package for now.</p>

        <button {testid("add-package-from-shoot")} type="button" phx-click="add-package" class="mt-2 text-center btn-primary intro-add-package">
          Add a package
        </button>

      <% else %>
        <ul class="text-left grid gap-5 lg:grid-cols-2 grid-cols-1">
          <%= for {shoot_number, shoot} <- @shoots do %>
            <li {testid("shoot-card")} class="border rounded-lg hover:bg-blue-planning-100 hover:border-blue-planning-300">
              <%= if shoot do %>
                <%= live_redirect to: @shoot_path.(shoot_number), title: "shoot #{shoot_number}", class: "block w-full p-4 text-left" do %>
                  <div class="flex items-center justify-between text-xl font-semibold">
                    <div>
                      <%= shoot.name %>
                    </div>

                    <.icon name="forth" class="w-4 h-4 stroke-current text-base-300 stroke-2" />
                  </div>

                  <div class="font-semibold text-blue-planning-300"> On <%= strftime(@current_user.time_zone, shoot.starts_at, "%B %d, %Y @ %I:%M %p") %> </div>

                  <hr class="my-3 border-top">

                  <span class="text-gray-400">
                    <%= shoot_location(shoot) %>
                  </span>
                <% end %>
              <% else %>
                <button title="Add shoot details" class="flex flex-col w-full h-full p-4 text-left" type="button" phx-click="edit-shoot-details" phx-value-shoot-number={shoot_number}>
                  <.badge color={:red}>Missing information</.badge>

                  <div class="flex items-center justify-between w-full mt-1 text-xl font-semibold">
                    <div>
                      Shoot <%= shoot_number %>
                    </div>

                    <.icon name="forth" class="w-4 h-4 stroke-current text-base-300 stroke-2" />
                  </div>
                </button>
              <% end %>
            </li>
          <% end %>
        </ul>
      <% end %>
    </.section>
    """
  end

  def booking_details_section(assigns) do
    ~H"""
    <.section id="booking-details" icon="camera-laptop" title="Booking details" collapsed_sections={@collapsed_sections}>
      <.card title={if @proposal, do: "Here’s what you sent your client", else: "Here’s what you’ll be sending your client"}>
        <div {testid("contract")} class="grid sm:grid-cols-2 gap-5">
          <div class="flex flex-col border border-base-200 rounded-lg p-4">
            <h3 class="font-bold">Contract:</h3>
            <%= cond do %>
              <% !@proposal -> %>
                <p class="mt-2">We’ve created a contract for you to start with. If you have your own or would like to tweak the language of ours—this is the place to change. We have Business Coaching available if you need advice.</p>
                <div class="border rounded-lg px-4 py-2 mt-4">
                  <span class="font-bold">Selected contract:</span> <%= if @job.contract, do: @job.contract.name, else: "Picsello Default Contract" %>
                </div>
                <button phx-click="edit-contract" class="mt-4 btn-primary self-end">
                  Edit or Select New
                </button>
              <% @package && @package.collected_price -> %>
                <p class="mt-2">During your job import, you marked this as an external document.</p>
              <% @job.contract -> %>
                <p class="mt-2">You sent the <%= @job.contract.name %> to your client.</p>
                <button {testid("view-contract")} phx-click="open-proposal" phx-value-action="contract" class="mt-4 btn-primary self-end">
                  View
                </button>
              <% true -> %>
            <% end %>
          </div>
          <div {testid("questionnaire")} class="flex flex-col border border-base-200 rounded-lg p-4">
            <h3 class="font-bold">Questionnaire:</h3>
            <%= cond do %>
              <% !@proposal -> %>
                <p class="mt-2">We’ve created a questionnaire for you to start with. Soon you’ll be able to include your own custom questionnaire whether it be a link or PDF. If you don’t want to use ours, uncheck the box below.</p>
                <label class="flex mt-4">
                  <input type="checkbox" class="w-6 h-6 mt-1 checkbox" phx-click="toggle-questionnaire" checked={@include_questionnaire} />
                  <p class="ml-3">Questionnaire included</p>
                </label>
                <button {testid("view-questionnaire")} phx-click="open-questionnaire" class="mt-auto btn-primary self-end">
                  View
                </button>
              <% @package && @package.collected_price -> %>
                <p class="mt-2">During your job import, you marked this as an external document.</p>
              <% @proposal.questionnaire_id -> %>
                <p class="mt-2">You sent the Picsello Default Questionnaire to your client.</p>
                <button {testid("view-questionnaire")} phx-click="open-proposal" phx-value-action="questionnaire" class="mt-4 btn-primary self-end">
                  View
                </button>
              <% true -> %>
                <p class="mt-2">Questionnaire wasn't included in the proposal</p>
            <% end %>
          </div>
        </div>
        <div class="grid md:grid-cols-3 mt-8">
          <dl class="flex flex-col">
            <dt class="font-bold">Payment schedule:</dt>
            <dd>
              <%= @job |> PaymentSchedules.build_payment_schedules_for_lead() |> Map.get(:details) %>
              <%= if @proposal do %>
                <button phx-click="open-proposal" phx-value-action="invoice" class="block link mt-2">View invoice</button>
              <% end %>
            </dd>
          </dl>
          <dl class="flex flex-col">
            <dt class="font-bold">Shoots:</dt>
            <dd>
              <%= cond do %>
                <% !@package -> %>
                  <.badge color={:red}>You haven’t selected a package yet</.badge>
                <% !Enum.all?(@shoots, &elem(&1, 1)) -> %>
                  <.badge color={:red}>Missing information in shoot details</.badge>
                <% true -> %>
                  <%= for {_, %{name: name, starts_at: starts_at}} <- @shoots do %>
                    <p><%= "#{name}—#{strftime(@current_user.time_zone, starts_at, "%m/%d/%Y")}" %></p>
                  <% end %>
              <% end %>
            </dd>
          </dl>
          <dl class="flex flex-col">
            <dt class="font-bold">Package:</dt>
            <dd>
              <%= if @package do %>
                <%= @package.name %>
              <% else %>
                <.badge color={:red}>You haven’t selected a package yet</.badge>
              <% end %>
            </dd>
          </dl>
        </div>
        <div class="flex justify-end items-center mt-8">
          <.icon_button icon="anchor" color="blue-planning-300" class="flex-shrink-0 mx-4 transition-colors" id="copy-client-link" data-clipboard-text={if @proposal, do: BookingProposal.url(@proposal.id)} phx-hook="Clipboard" disabled={!@proposal}>
            <span>Copy client link</span>
            <div class="hidden p-1 text-sm rounded shadow" role="tooltip">
              Copied!
            </div>
          </.icon_button>
          <%= if @proposal do %>
            <button class="btn-primary" phx-click="open-proposal" phx-value-action="details">View proposal</button>
          <% else %>
            <%= render_slot(@send_proposal_button) %>
          <% end %>
        </div>
      </.card>
    </.section>
    """
  end

  def history_card(assigns) do
    ~H"""
    <div {testid("history")} class="bg-base-200 p-4 px-8 rounded-lg mt-4 md:mt-0 md:ml-6 md:w-72">
      <h3 class="mb-2 text-xl font-bold"><%= @steps_title %></h3>
      <ul class="list-disc">
        <%= for item <- @steps do %>
          <li class="ml-4"><%= item %></li>
        <% end %>
      </ul>
      <h3 class="mt-4 text-xl font-bold">History</h3>
      <%= live_component PicselloWeb.JobLive.Shared.HistoryComponent, job: @job, current_user: @current_user %>
    </div>
    """
  end

  @spec shoot_details(%{
          current_user: %Picsello.Accounts.User{},
          shoot_path: fun(),
          job: %Picsello.Job{},
          shoots: list(%Picsello.Shoot{}),
          socket: %Phoenix.LiveView.Socket{}
        }) :: %Phoenix.LiveView.Rendered{}
  def shoot_details(assigns) do
    ~H"""

    """
  end

  def job_form_fields(assigns) do
    assigns = assigns |> Enum.into(%{email: nil, name: nil, phone: nil})

    ~H"""
    <div class="px-1.5 grid grid-cols-1 sm:grid-cols-2 gap-5">
      <%= inputs_for @form, :client, fn client_form -> %>
        <%= labeled_input client_form, :name, label: "Client Name", placeholder: "First and last name", autocapitalize: "words", autocorrect: "false", spellcheck: "false", autocomplete: "name", phx_debounce: "500", disabled: @name != nil %>
        <%= if @name != nil do %>
          <%= hidden_input client_form, :name %>
        <% end %>
        <%= labeled_input client_form, :email, type: :email_input, label: "Client Email", placeholder: "email@example.com", phx_debounce: "500", disabled: @email != nil %>
        <%= if @email != nil do %>
          <%= hidden_input client_form, :email %>
        <% end %>
        <%= labeled_input client_form, :phone, type: :telephone_input, label: "Client Phone", placeholder: "(555) 555-5555", phx_hook: "Phone", phx_debounce: "500", disabled: @phone != nil  %>
        <%= if @phone != nil do %>
          <%= hidden_input client_form, :phone %>
        <% end %>
      <% end %>

      <%= labeled_select @form, :type, for(type <- @job_types, do: {humanize(type), type}), label: "Type of Photography", prompt: "Select below" %>

      <div class="sm:col-span-2">
        <div class="flex items-center justify-between mb-2">
          <%= label_for @form, :notes, label: "Private Notes" %>
          <.icon_button color="red-sales-300" icon="trash" phx-hook="ClearInput" id="clear-notes" data-input-name={input_name(@form,:notes)}>
            Clear
          </.icon_button>
        </div>
        <%= input @form, :notes, type: :textarea, placeholder: "Optional notes", class: "w-full", phx_hook: "AutoHeight", phx_update: "ignore" %>
      </div>
    </div>
    """
  end

  def assign_job(%{assigns: %{current_user: current_user, live_action: :leads}} = socket, job_id) do
    job =
      current_user
      |> Job.for_user()
      |> Ecto.Query.preload([:client, :package, :job_status, :gallery, :contract])
      |> Repo.get!(job_id)

    if job.job_status.is_lead do
      socket
      |> do_assign_job(job)
    else
      push_redirect(socket, to: Routes.job_path(socket, :jobs, job_id))
    end
  end

  def assign_job(%{assigns: %{current_user: current_user, live_action: :jobs}} = socket, job_id) do
    job =
      current_user
      |> Job.for_user()
      |> Job.not_leads()
      |> Ecto.Query.preload([
        :client,
        :package,
        :job_status,
        :contract,
        :gallery,
        :payment_schedules
      ])
      |> Repo.get!(job_id)

    do_assign_job(socket, job)
  end

  defp do_assign_job(socket, job) do
    socket
    |> assign(
      job: job,
      page_title: job |> Job.name(),
      package: job.package
    )
    |> assign_shoots()
    |> assign_proposal()
    |> assign_inbox_count()
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
