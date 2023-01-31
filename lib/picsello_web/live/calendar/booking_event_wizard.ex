defmodule PicselloWeb.Live.Calendar.BookingEventWizard do
  @moduledoc false

  use PicselloWeb, :live_component
  import PicselloWeb.ShootLive.Shared, only: [duration_options: 0, location: 1]
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.PackageLive.Shared, only: [package_card: 1, current: 1]
  import PicselloWeb.Shared.ImageUploadInput, only: [image_upload_input: 1]
  import PicselloWeb.Shared.Quill, only: [quill_input: 1]
  import PicselloWeb.ClientBookingEventLive.Shared, only: [blurred_thumbnail: 1]

  alias Picsello.{BookingEvent, BookingEvents, Packages}

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_new(:step, fn -> :details end)
    |> assign_new(:steps, fn -> [:details, :package, :customize] end)
    |> assign_new(:collapsed_dates, fn -> [] end)
    |> assign_new(:booking_event, fn -> %BookingEvent{} end)
    |> case do
      %{assigns: %{booking_event: %BookingEvent{id: nil}}} = socket ->
        socket |> assign_changeset(%{"dates" => [%{"time_blocks" => [%{}]}]})

      socket ->
        socket |> assign_changeset(%{})
    end
    |> assign_package_templates()
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <.close_x />

      <a {if step_number(@step, @steps) > 1, do: %{href: "#", phx_click: "back", phx_target: @myself, title: "back"}, else: %{}} class="flex">
        <span {testid("step-number")} class="px-2 py-0.5 mr-2 text-xs font-semibold rounded bg-blue-planning-100 text-blue-planning-300">
          Step <%= step_number(@step, @steps) %>
        </span>

        <ul class="flex items-center inline-block">
          <%= for step <- @steps do %>
            <li class={classes(
              "block w-5 h-5 sm:w-3 sm:h-3 rounded-full ml-3 sm:ml-2",
              %{ "bg-blue-planning-300" => step == @step, "bg-gray-200" => step != @step }
              )}>
            </li>
          <% end %>
        </ul>
      </a>

      <.step_heading name={@step} is_edit={@booking_event.id} />

      <.form for={@changeset} let={f} phx_change={:validate} phx_submit={:submit} phx_target={@myself} id={"form-#{@step}"}>
        <input type="hidden" name="step" value={@step} />

        <.wizard_state form={f} />

        <.step name={@step} f={f} {assigns} />

        <.footer>
          <.step_buttons name={@step} form={f} is_valid={@changeset.valid?} myself={@myself} />

          <%= if step_number(@step, @steps) == 1 do %>
            <button class="btn-secondary" title="cancel" type="button" phx-click="modal" phx-value-action="close">
              Cancel
            </button>
          <% else %>
            <button class="btn-secondary" title="back" type="button" phx-click="back" phx-target={@myself}>
              Go back
            </button>
          <% end %>
        </.footer>
      </.form>
    </div>
    """
  end

  def wizard_state(assigns) do
    ~H"""
      <%= for field <- BookingEvent.__schema__(:fields) -- [:dates], input_value(@form, field) do %>
        <%= hidden_input @form, field, id: nil %>
      <% end %>

      <%= inputs_for @form, :dates, fn d -> %>
        <%= for field <- BookingEvent.EventDate.__schema__(:fields) -- [:time_blocks], input_value(d, field) do %>
          <%= hidden_input d, field, id: nil %>
        <% end %>

        <%= inputs_for d, :time_blocks, fn t -> %>
          <%= for field <- BookingEvent.TimeBlock.__schema__(:fields), input_value(t, field) do %>
            <%= hidden_input t, field, id: nil %>
          <% end %>
        <% end %>
      <% end %>
    """
  end

  def step_heading(assigns) do
    ~H"""
      <h1 class="mt-2 mb-4 text-3xl"><strong class="font-bold"><%= heading_title(@is_edit) %>:</strong> <%= heading_subtitle(@name) %></h1>
    """
  end

  def heading_title(is_edit), do: if(is_edit, do: "Edit booking event", else: "Add booking event")

  def heading_subtitle(step) do
    Map.get(
      %{
        details: "Details",
        package: "Select package",
        customize: "Customize"
      },
      step
    )
  end

  def step_buttons(%{name: step} = assigns) when step in [:details, :package] do
    ~H"""
    <button class="btn-primary" title="Next" type="submit" disabled={!@is_valid} phx-disable-with="Next">
      Next
    </button>
    """
  end

  def step_buttons(%{name: :customize} = assigns) do
    ~H"""
    <button class="btn-primary" title="Save" type="submit" disabled={!@is_valid} phx-disable-with="Save">
      Save
    </button>
    """
  end

  def step(%{name: :details} = assigns) do
    ~H"""
      <div class="flex flex-col mt-4">
        <h2 class="text-xl font-bold">Set your details</h2>
        <p>Add in your session details and location to populate the event landing page and set your availability appropriately.</p>
        <div class="grid gap-5 sm:grid-cols-6 mt-4">
          <%= labeled_input @f, :name, label: "Title", placeholder: "Fall Mini-sessions", wrapper_class: "sm:col-span-2" %>
          <.location f={@f} myself={@myself} allow_address_toggle={false} address_field={true} />
          <%= labeled_select @f, :duration_minutes, duration_options(), label: "Session Length", prompt: "Select below", wrapper_class: "sm:col-span-3" %>
          <%= labeled_select @f, :buffer_minutes, buffer_options(), label: "Session Buffer", prompt: "Select below", wrapper_class: "sm:col-span-3", optional: true %>
        </div>
        <h2 class="text-xl font-bold mt-4">Event date(s)</h2>
        <p>You can create single- or multi-day events with specified time blocks each day. We will calculate the amount of slots you can do each day. Don’t forget to take a meal break!</p>

        <%= error_tag(@f, :dates, prefix: "Dates", class: "text-red-sales-300 text-sm mt-2") %>
        <%= inputs_for @f, :dates, fn d -> %>
          <.event_date event_form={@f} f={d} id={"event-#{d.index}"} myself={@myself} collapsed_dates={@collapsed_dates} />
        <% end %>

        <div class="mt-8">
          <.icon_button {testid("add-date")} phx-click="add-date" phx-target={@myself} class="py-1 px-4 w-full sm:w-auto justify-center" title="Add another date" color="blue-planning-300" icon="plus">
            Add another date
          </.icon_button>
        </div>
      </div>
    """
  end

  def step(%{name: :package} = assigns) do
    ~H"""
    <div class="grid grid-cols-1 my-4 sm:grid-cols-2 lg:grid-cols-3 gap-7">
      <%= for package <- @package_templates do %>
        <% checked = is_checked(input_value(@f, :package_template_id), package) %>

        <label {testid("template-card")}>
          <input class="hidden" type="radio" name={input_name(@f, :package_template_id)} value={if checked, do: "", else: package.id} />
          <.package_card package={package} class={classes(%{"bg-blue-planning-100 border-blue-planning-300" => checked})}/>
        </label>
      <% end %>
    </div>
    """
  end

  def step(%{name: :customize} = assigns) do
    ~H"""
    <div class="flex flex-col mt-4">
      <h2 class="text-xl font-bold">Customize your booking event</h2>
      <p>Upload an image and write a short description to entice clients to book a session with you.</p>

      <div class="grid sm:grid-cols-2 gap-7 mt-2">
        <div>
          <label for={input_name(@f, :thumbnail_url)} class="input-label">Thumbnail</label>
          <.image_upload_input
            current_user={@current_user}
            upload_folder="booking_event_image"
            name={input_name(@f, :thumbnail_url)}
            url={input_value(@f, :thumbnail_url)}
            class="aspect-[3/2] mt-2"
          >
            <:image_slot>
              <.blurred_thumbnail class="h-full w-full" url={input_value(@f, :thumbnail_url)} />
            </:image_slot>
          </.image_upload_input>
        </div>
        <div>
          <label for={input_name(@f, :description)} class="input-label">Short Description</label>
          <.quill_input
            f={@f}
            html_field={:description}
            current_user={@current_user}
            class="aspect-[5/3] mt-2"
            placeholder="Use this area to describe your mini-session event or limited-edition session. Describe what is included in the package (eg, the location, length of time, digital images etc)."
          />
        </div>
      </div>
    </div>
    """
  end

  def event_date(assigns) do
    ~H"""
    <section {testid("event-date")} class="border border-base-200 rounded-lg mt-4 overflow-hidden">
      <div class="flex bg-base-200 px-4 py-2 items-center cursor-pointer" phx-click="toggle-collapsed-date" phx-value-index={@f.index} phx-target={@myself}>
        <h2 class="text-lg font-bold py-1">Day <%= @f.index + 1 %></h2>
        <%= if @f.index > 0 do %>
          <.icon_button class="ml-4" title="remove date" phx-click="remove-date" phx-value-index={@f.index} phx-target={@myself} color="red-sales-300" icon="trash">
            Remove
          </.icon_button>
        <% end %>
        <div class="ml-auto">
          <%= if Enum.member?(@collapsed_dates, @f.index) do %>
            <.icon name="down" class="w-3 h-3 stroke-current stroke-3" />
          <% else %>
            <.icon name="up" class="w-3 h-3 stroke-current stroke-3" />
          <% end %>
        </div>
      </div>
      <div class={classes("p-4 grid gap-5 sm:grid-cols-2", %{"hidden" => Enum.member?(@collapsed_dates, @f.index)})}>
        <div class="flex flex-col">
          <%= labeled_input @f, :date, type: :date_input, label: "Select Date", min: Date.utc_today() %>
          <%= case calculate_slots_count(@event_form, input_value(@f, :date)) do %>
            <% count -> %>
              <p {testid("open-slots-count-#{@f.index}")} class="mt-2 font-semibold">You’ll have <span class="text-blue-planning-300"><%= count %></span><%= ngettext " open slot", " open slots", count %> on this day</p>
          <% end %>
        </div>
        <div>
          <p class="input-label">What times are you available this day?</p>
          <%= error_tag(@f, :time_blocks, prefix: "Times", class: "text-red-sales-300 text-sm mb-2") %>
          <%= inputs_for @f, :time_blocks, fn t -> %>
            <div class="flex items-center mb-2">
              <%= input t, :start_time, type: :time_input %>
              <p class="mx-2">-</p>
              <%= input t, :end_time, type: :time_input %>
              <%= if t.index > 0 do %>
                <.icon_button class="ml-4" title="remove time" phx-click="remove-time-block" phx-value-index={@f.index} phx-value-time-block-index={t.index} phx-target={@myself} color="red-sales-300" icon="trash" />
              <% end %>
            </div>
          <% end %>
          <.icon_button class="py-1 px-4 mt-4 w-full sm:w-auto justify-center" title="Add block" phx-click="add-time-block" phx-value-index={@f.index} phx-target={@myself} color="blue-planning-300" icon="plus">
            Add block
          </.icon_button>
        </div>
      </div>
    </section>
    """
  end

  @impl true
  def handle_event("back", %{}, %{assigns: %{step: step, steps: steps}} = socket) do
    previous_step = Enum.at(steps, Enum.find_index(steps, &(&1 == step)) - 1)

    socket
    |> assign(step: previous_step)
    |> noreply()
  end

  def handle_event(
        "toggle-collapsed-date",
        %{"index" => index},
        %{assigns: %{collapsed_dates: collapsed_dates}} = socket
      ) do
    {index, _} = Integer.parse(index)

    collapsed_dates =
      if Enum.member?(collapsed_dates, index) do
        Enum.filter(collapsed_dates, &(&1 != index))
      else
        collapsed_dates ++ [index]
      end

    socket
    |> assign(:collapsed_dates, collapsed_dates)
    |> noreply()
  end

  @impl true
  def handle_event("add-date", %{}, %{assigns: %{changeset: changeset}} = socket) do
    dates = changeset |> Ecto.Changeset.get_field(:dates)
    changeset = changeset |> Ecto.Changeset.put_embed(:dates, dates ++ [%{time_blocks: [%{}]}])

    socket
    |> assign(changeset: changeset)
    |> noreply()
  end

  @impl true
  def handle_event(
        "remove-date",
        %{"index" => index},
        %{assigns: %{changeset: changeset, collapsed_dates: collapsed_dates}} = socket
      ) do
    {index, _} = Integer.parse(index)
    dates = changeset |> Ecto.Changeset.get_field(:dates) |> List.delete_at(index)
    changeset = changeset |> Ecto.Changeset.put_embed(:dates, dates)

    collapsed_dates = collapsed_dates |> List.delete_at(index)

    socket
    |> assign(changeset: changeset, collapsed_dates: collapsed_dates)
    |> noreply()
  end

  @impl true
  def handle_event(
        "add-time-block",
        %{"index" => index},
        %{assigns: %{changeset: changeset}} = socket
      ) do
    {index, _} = Integer.parse(index)

    dates =
      changeset
      |> Ecto.Changeset.get_field(:dates)
      |> Enum.map(&Map.from_struct/1)
      |> List.update_at(index, fn date ->
        date |> Map.put(:time_blocks, (date.time_blocks || []) ++ [%{}])
      end)

    changeset =
      changeset
      |> Ecto.Changeset.put_embed(:dates, dates)

    socket
    |> assign(changeset: changeset)
    |> noreply()
  end

  @impl true
  def handle_event(
        "remove-time-block",
        %{"index" => index, "time-block-index" => time_block_index},
        %{assigns: %{changeset: changeset}} = socket
      ) do
    {index, _} = Integer.parse(index)
    {time_block_index, _} = Integer.parse(time_block_index)

    dates =
      changeset
      |> Ecto.Changeset.get_field(:dates)
      |> Enum.map(&Map.from_struct/1)
      |> List.update_at(index, fn date ->
        time_blocks =
          date.time_blocks
          |> Enum.map(&Map.from_struct/1)
          |> List.delete_at(time_block_index)

        date |> Map.put(:time_blocks, time_blocks)
      end)

    changeset =
      changeset
      |> Ecto.Changeset.put_embed(:dates, dates)
      |> Map.put(:action, :validate)

    socket
    |> assign(changeset: changeset)
    |> noreply()
  end

  @impl true
  def handle_event("validate", %{"booking_event" => params}, socket) do
    socket |> assign_changeset(params, :validate) |> noreply()
  end

  @impl true
  def handle_event("submit", %{"step" => step, "booking_event" => params}, socket)
      when step in ["details", "package"] do
    case socket |> assign_changeset(params, :validate) do
      %{assigns: %{changeset: %{valid?: true}}} ->
        socket
        |> assign(step: next_step(socket.assigns))
        |> assign_changeset(params)

      socket ->
        socket
    end
    |> noreply()
  end

  @impl true
  def handle_event("submit", %{"step" => "customize", "booking_event" => params}, socket) do
    %{assigns: %{changeset: changeset}} = socket = assign_changeset(socket, params)

    case BookingEvents.upsert_booking_event(changeset) do
      {:ok, booking_event} ->
        successfull_save(socket, booking_event)

      _ ->
        socket |> noreply()
    end
  end

  defp successfull_save(socket, booking_event) do
    send(self(), {:update, %{booking_event: booking_event}})

    socket
    |> close_modal()
    |> noreply()
  end

  defp assign_changeset(
         %{assigns: %{booking_event: booking_event, step: step}} = socket,
         params,
         action \\ nil
       ) do
    changeset =
      booking_event |> BookingEvent.changeset(params, step: step) |> Map.put(:action, action)

    assign(socket, changeset: changeset)
  end

  defp assign_package_templates(%{assigns: %{current_user: current_user}} = socket) do
    packages = Packages.templates_with_single_shoot(current_user)

    socket |> assign(package_templates: packages)
  end

  defp step_number(name, steps), do: Enum.find_index(steps, &(&1 == name)) + 1

  defp next_step(%{step: step, steps: steps}) do
    Enum.at(steps, Enum.find_index(steps, &(&1 == step)) + 1)
  end

  def buffer_options() do
    for(
      duration <- [5, 10, 15, 20, 30, 45, 60],
      do: {dyn_gettext("duration-#{duration}"), duration}
    )
  end

  defp calculate_slots_count(event_form, date) do
    event = current(event_form)
    event |> BookingEvents.available_times(date, skip_overlapping_shoots: true) |> Enum.count()
  end

  defp is_checked(id, package) do
    if id do
      id |> to_integer() == package.id
    else
      false
    end
  end
end
