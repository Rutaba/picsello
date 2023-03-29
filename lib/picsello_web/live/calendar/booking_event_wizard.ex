defmodule PicselloWeb.Live.Calendar.BookingEventWizard do
  @moduledoc false

  use PicselloWeb, :live_component
  alias Picsello.{BookingEvent, BookingEvents, Packages}

  import PicselloWeb.ShootLive.Shared, only: [duration_options: 0, location: 1]
  import PicselloWeb.LiveModal, only: [close_x: 1, footer: 1]
  import PicselloWeb.PackageLive.Shared, only: [package_row: 1, current: 1]
  import PicselloWeb.Shared.ImageUploadInput, only: [image_upload_input: 1]
  import PicselloWeb.Shared.Quill, only: [quill_input: 1]
  import PicselloWeb.ClientBookingEventLive.Shared, only: [blurred_thumbnail: 1]

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign(assign_event_keys(assigns))
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

  def assign_event_keys(assigns) do
    assigns
    |> Map.put_new(:can_edit?, true)
    |> Map.put_new(:booking_count, 0)
    |> Map.put_new(:break_block_booked, false)
    |> Map.put_new(:params, %{})
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

      <.form for={@changeset} :let={f} phx_change={:validate} phx_submit={:submit} phx_target={@myself} id={"form-#{@step}"}>
        <input type="hidden" name="step" value={@step} />

        <.wizard_state form={f} />

        <.step name={@step} f={f} {assigns} />

        <.footer>
          <.step_buttons name={@step} form={f} is_valid={@changeset.valid?} break_block_booked = {@break_block_booked} myself={@myself} />

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
    <button class="btn-primary" title="Next" type="submit" disabled={!@is_valid || @break_block_booked} phx-disable-with="Next">
      Next
    </button>
    """
  end

  def step_buttons(%{name: :customize} = assigns) do
    ~H"""
    <button class="btn-primary" title="Save" type="submit" disabled={!@is_valid || @break_block_booked} phx-disable-with="Save">
      Save
    </button>
    """
  end

  def step(%{name: :details, can_edit?: can_edit?, booking_count: booking_count} = assigns) do
    ~H"""
      <div class="flex flex-col mt-4">
        <h2 class="text-xl font-bold">Set your details</h2>
        <p>Add in your session details and location to populate the event landing page and set your availability appropriately.</p>
        <div class="grid gap-5 sm:grid-cols-6 mt-4">
          <%= labeled_input @f, :name, label: "Title", placeholder: "Fall Mini-sessions", wrapper_class: "sm:col-span-2" %>
          <.location f={@f} myself={@myself} allow_address_toggle={false} address_field={true} is_edit={can_edit?}/>
          <%= labeled_select @f, :duration_minutes, duration_options(), label: "Session Length", prompt: "Select below", wrapper_class: "sm:col-span-3", disabled: !can_edit? %>
          <%= labeled_select @f, :buffer_minutes, buffer_options(), label: "Session Buffer", prompt: "Select below", wrapper_class: "sm:col-span-3", optional: true, disabled: !can_edit? %>
        </div>
        <h2 class="text-xl font-bold mt-4">Event date(s)</h2>
        <p>You can create single- or multi-day events with specified time blocks each day. We will calculate the amount of slots you can do each day. Don’t forget to take a meal break!</p>

        <%= error_tag(@f, :dates, prefix: "Dates", class: "text-red-sales-300 text-sm mt-2") %>
        <%= inputs_for @f, :dates, fn d -> %>
          <.event_date event_form={@f} f={d} id={"event-#{d.index}"} myself={@myself} collapsed_dates={@collapsed_dates} changeset={@changeset} booking_count={booking_count} is_edit={can_edit?}/>
        <% end %>

        <div class="mt-8">
          <.icon_button {testid("add-date")} phx-click="add-date" phx-target={@myself} class="py-1 px-4 w-full sm:w-auto justify-center" title="Add another date" color="blue-planning-300" icon="plus">
            Add another date
          </.icon_button>
        </div>
      </div>
    """
  end

  def step(%{name: :package, can_edit?: can_edit?} = assigns) do
    ~H"""
     <%= if !can_edit? do %>
        <div class="flex rounded-lg h-fit mt-8 p-1 ml-3 flex flex-row border bg-base-200">
          <.icon name="warning-orange" class="w-4 h-4 mt-2 mr-2" />
          <div class="warning-text">
            <p class="font-bold">Since you have bookings already, you  won’t be able to change your package.</p>
            <p class="font-normal">If you need to change that, archive or disable your booking event and make a new one.</p>
          </div>
        </div>
    <% end %>
    <%= if @package_templates == [] do %>
      <div class="flex flex-col rounded-lg h-fit md:mb-10 sm:mb-2 mt-8 p-1 border bg-base-200">
        <div class="w-10 h-6 mt-2 ml-2 rounded-lg bg-blue-planning-300 text-center">
          <span class="text-base-100"> TIP </span>
        </div>
        <div class="mt-2 ml-2 w-fit lg:w-11/12">
          <p class="font-normal text-lg text-gray-400">If you aren’t seeing your package here, you need to make sure the package only has 1 shoot set. We calculate the # of sessions based off of that.
            <a class="items-center text-blue-planning-300 underline font-normal" href={Routes.package_templates_path(@socket, :index)} target="_blank"> Manage your packages here<.icon name="external-link" class=" inline ml-2 w-4 h-4" /></a>
          </p>
        </div>
      </div>
    <% end %>
    <div class={classes("hidden sm:flex items-center border-b-8 border-blue-planning-300 font-semibold text-lg pb-3 mt-4 text-base-250", %{"justify-between" => can_edit?})}>
      <%= for title <- ["Package name", "Package Pricing", "Select package"] do %>
        <%= if (!can_edit? and title !=  "Select package") || can_edit? do %>
            <div class={classes("w-1/3", %{"last:text-center" => can_edit?})}><%= title %></div>
        <% end %>

      <% end %>
    </div>
    <%= if @package_templates == [] do %>
      <div class="flex flex-col md:flex-row mt-2 lg:mt-8">
          <img src="/images/empty-state.png" class="my-auto block"/>
          <div class="justify-center p-1 md:ml-6 flex flex-col sm:mt-4">
            <div class="font-bold">Missing packages</div>
            <div>
              <div class="font-normal pb-6 text-base-250 w-fit lg:w-96">
                You don’t have any packages with a single shoot! You’ll need to create some packages before you can select one.(Modal will close when you click “Package Settings”)
              </div>
              <a id="gallery-settings" class="w-48 btn-tertiary text-center flex-row items-center pt-3 text-grey-planning-300" href={Routes.package_templates_path(@socket, :index)} title="Package Settings">
                <.icon name="gear" class="inline-block w-6 h-6 mr-2 text-blue-planning-300"/>
                  Package Settings
              </a>
            </div>
          </div>
      </div>
    <% end %>
    <%= if can_edit? do %>
        <%= for package <- @package_templates do %>
          <% checked = is_checked(input_value(@f, :package_template_id), package) %>
          <label class={classes(%{"cursor-not-allowed pointer-events-none" => !can_edit?})}>
            <.package_row package={package} checked={checked}>
              <input class={classes("w-5 h-5 mr-2.5 radio", %{"checked" => checked})} type="radio" name={input_name(@f, :package_template_id)} value={if checked, do: nil, else: package.id} />
            </.package_row>
          </label>
        <% end %>
    <% else %>
      <% package_id = input_value(@f, :package_template_id) |> to_integer() %>
      <% package = Enum.filter(@package_templates, fn template -> template.id == package_id end) |> List.first() %>
      <%= if package do %>
        <label class={classes(%{"cursor-not-allowed pointer-events-none" => !can_edit?})}>
            <.package_row package={package} can_edit?={can_edit?}/>
        </label>
      <% else %>
        <div class="flex rounded-lg h-fit  mt-8 p-2 ml-3 flex flex-row border bg-base-200">
            <.icon name="warning-orange" class="w-4 h-4 mt-2 mr-2" />
            <div class="warning-text">
              <p class="font-bold">There is no package for this user <br/></p>
            </div>
        </div>
      <% end %>
    <% end %>
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
          <.icon_button class="ml-4" title="remove date" disabled= {is_date_booked(@event_form, input_value(@f, :date))} phx-click="remove-date" phx-value-index={@f.index} phx-target={@myself} color="red-sales-300" icon="trash">
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
      <div class={classes("p-4 grid gap-5 lg:grid-cols-3 grid-cols-1", %{"hidden" => Enum.member?(@collapsed_dates, @f.index)})} {intro_hints_only("intro_hints_only")}>
        <div class="flex flex-col">
          <%= labeled_input @f, :date, type: :date_input, label: "Select Date", min: Date.utc_today(), disabled: is_date_booked(@event_form, input_value(@f, :date)) %>
          <%= if is_date_booked(@event_form, input_value(@f, :date)) do %>
            <div class="flex justify-start mt-4 items-center">
              <.icon name="warning-red", class="w-10 h-10 red-sales-300 stroke-[4px]" />
              <div class="pl-4 text-gray-400">You can’t change the date since you have bookings. You can add another date though!</div>
            </div>
          <% end %>
        </div>
        <div class="col-span-2">
          <p class="input-label">What times are you available this day?</p>
          <%= error_tag(@f, :time_blocks, prefix: "Times", class: "text-red-sales-300 text-sm mb-2") %>
          <%= inputs_for @f, :time_blocks, fn t -> %>
            <div class="flex lg:items-center flex-col lg:flex-row mb-4">
              <div class={classes("flex items-center lg:w-auto w-full lg:justify-start justify-between", %{"text-gray-400" => (t |> current |> Map.get(:is_booked)) and !(t |> current |> Map.get(:is_break))})}>
                <%= input t, :start_time, type: :time_input, disabled: (t |> current |> Map.get(:is_booked)) and !(t |> current |> Map.get(:is_break))%>
                <p class="mx-2">-</p>
                <%= input t, :end_time, type: :time_input, disabled: (t |> current |> Map.get(:is_booked)) and !(t |> current |> Map.get(:is_break)) %>
                <%= hidden_input t, :is_break%>
                <%= hidden_input t, :is_valid, value: t |> current |> Map.get(:is_valid) %>
              </div>
              <div class="flex justify-between w-full mt-2 lg:mt-0">
                  <%= if get_is_break!(@changeset, @f.index,t.index) do %>
                    <span class="italic text-base-250 ml-2"> Break Block <.intro_hint class="ml-2 hidden lg:inline-block" content="Breaks are important so you can catch your breath!"/></span>
                  <% end %>
                  <%= if get_is_hidden!(@changeset, @f.index,t.index) do %>
                    <span class="italic text-base-250 ml-2"> Hidden Block <.intro_hint class="ml-2 hidden lg:inline-block" content="This is a great way to add some urgency for clients to book!"/></span>
                  <% end %>
                <div class="flex ml-auto">
                  <div data-offset="0" phx-hook="Select" id={"manage-event-#{@f.index}-#{t.index}"} class={classes(%{"pointer-events-none opacity-40" => t |> current |> Map.get(:is_break)})}>
                    <button title="Manage" type="button" class="flex flex-shrink-0 ml-2 px-2 bg-white border rounded-lg border-blue-planning-300 text-blue-planning-300">
                      <.icon name="gear" class="w-4 h-5 m-1 fill-current open-icon text-blue-planning-300" />
                      <.icon name="close-x" class="hidden w-4 h-5 m-1 stroke-current close-icon stroke-2 text-blue-planning-300" />
                    </button>
                    <div class="hidden bg-white border rounded-lg shadow-lg popover-content p-2">
                      <h2 class="font-bold"> Block Options </h2>
                      <label class="flex items-center mt-4">
                        <%= input t, :is_hidden, type: :checkbox, checked: t |> current |> Map.get(:is_hidden), class: "w-6 h-6 mt-1 checkbox", id: "check-box-#{@f.index}-#{t.index}"%>
                        <p class="font-bold ml-3"> Show block as hidden (booked)</p>
                      </label>
                      <p class="text-base-250 ml-8">In case you want to save some <br/> booking slots for later</p>
                    </div>
                  </div>
                  <.icon_button {testid("remove-time-#{t.index}")} class={classes("ml-4 py-1",%{"pointer-events-none" => (t |> current |> Map.get(:is_booked)) and !(t |> current |> Map.get(:is_break))})} title="remove time" disabled={(t |> current |> Map.get(:is_booked)) and !(t |> current |> Map.get(:is_break))} phx-click="remove-time-block" phx-value-index={@f.index} phx-value-time-block-index={t.index} phx-target={@myself} color="red-sales-300" icon="trash" />
                </div>
              </div>
            </div>
            <%= if ((t |> current |> Map.get(:is_booked)) and !(t |> current |> Map.get(:is_break))) do %>
              <div class="flex justify-start mb-4 items-center">
                <.icon name="warning-red", class="w-10 h-5 red-sales-300 stroke-[4px]" />
                <div class="pl-2 text-gray-400">You have bookings in this slot. You won’t be able to edit but you can hide it!.</div>
              </div>
            <% end %>
            <%= if !(t |> current |> Map.get(:is_valid))do %>
                <div class="flex justify-start mb-4 items-center">
                    <.icon name="warning-red", class="w-10 h-5 red-sales-300 stroke-[4px]" />
                    <div class="pl-2 text-gray-400">Sorry, you have time slots booked during the time you are requesting as a break. Please select a different time.</div>
                </div>
            <% end %>
          <% end %>
          <div class="flex flex-row">
            <.icon_button class="py-1 lg:px-4 px-0 w-full sm:w-auto justify-center" title="Add block" phx-click="add-time-block" phx-value-index={@f.index}  phx-value-break={"false"} phx-target={@myself} color="blue-planning-300" icon="plus">
              Add block
            </.icon_button>
            <.icon_button class="py-1 lg:px-4 px-2 lg:ml-4 ml-2 w-full sm:w-auto justify-center" title="Add Break block" phx-click="add-time-block" phx-value-index={@f.index}  phx-value-break={"true"} phx-target={@myself} color="blue-planning-300" icon="plus">
              Add break block
            </.icon_button>
          </div>
          <%= case calculate_slots_count(@event_form, input_value(@f, :date), @is_edit) do %>
            <% {slot_count, break_count, hidden_count, booked_slots} -> %>
              <p {testid("open-slots-count-#{@f.index}")} class="mt-2 font-semibold">You’ll have <span class="text-blue-planning-300"><%= slot_count %></span><%= ngettext " open slot", " open slots", slot_count %>, <span class="text-blue-planning-300"><%= hidden_count %></span><%= ngettext " hidden block", " hidden block", hidden_count %> and <span class="text-blue-planning-300"><%= break_count %> </span><%= ngettext "break block", " break block", break_count %>, and <span class="text-blue-planning-300"><%= booked_slots %></span> already booked on this day</p>
          <% end %>
        </div>
      </div>
    </section>
    """
  end

  @impl true
  def handle_event("back", %{}, %{assigns: %{step: step, steps: steps, params: params}} = socket) do
    previous_step = Enum.at(steps, Enum.find_index(steps, &(&1 == step)) - 1)

    socket
    |> assign(step: previous_step)
    |> assign_changeset(params)
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
        %{"index" => index, "break" => break},
        %{assigns: %{changeset: changeset}} = socket
      ) do
    is_break = convert_bool(break)
    {index, _} = Integer.parse(index)

    dates =
      changeset
      |> Ecto.Changeset.get_field(:dates)
      |> Enum.map(&Map.from_struct/1)
      |> List.update_at(index, fn date ->
        date
        |> Map.put(:time_blocks, (date.time_blocks || []) ++ [%{is_break: is_break}])
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

    time_blocks = dates |> Enum.at(index) |> Map.get(:time_blocks)

    dates =
      if Enum.empty?(time_blocks) do
        dates
        |> List.update_at(index, fn date ->
          date
          |> Map.put(:date, nil)
          |> Map.put(:time_blocks, [%{start_time: nil, end_time: nil, is_break: false}])
        end)
      else
        dates
      end

    changeset =
      changeset
      |> Ecto.Changeset.put_change(:dates, dates)
      |> Map.put(:action, :validate)

    params =
      changeset.params
      |> Map.put("dates", convert_dates(dates))

    socket |> assign_changeset(params, :validate) |> noreply()
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
        |> assign(params: params)
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

    dates =
      changeset
      |> Ecto.Changeset.get_field(:dates)
      |> Enum.map(&Map.from_struct/1)
      |> BookingEvents.assign_booked_block_dates(booking_event)

    break_block_booked = is_break_block_already_booked(dates)
    block_booked = is_any_block_booked(dates)

    changeset =
      if changeset.valid? do
        changeset
        |> Ecto.Changeset.put_embed(:dates, dates)
      else
        changeset
      end

    assign(socket,
      changeset: changeset,
      break_block_booked: break_block_booked,
      can_edit?: !block_booked
    )
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

  defp calculate_slots_count(event_form, date, can_edit?) do
    event = current(event_form)

    slot_count =
      event |> BookingEvents.available_times(date, skip_overlapping_shoots: true) |> Enum.count()

    booked_slots_count =
      case can_edit? do
        true -> 0
        false -> calculate_booked_slots(event, date)
      end

    {slot_count, calculate_break_blocks(event, date), calculate_hidden_blocks(event, date),
     booked_slots_count}
  end

  defp is_break_block_already_booked(dates) do
    dates
    |> Enum.filter(fn %{time_blocks: time_blocks} ->
      Enum.filter(time_blocks, fn block ->
        !block.is_valid
      end)
      |> Enum.count() > 0
    end)
    |> Enum.count() > 0
  end

  defp is_any_block_booked(dates) do
    dates
    |> Enum.filter(fn %{time_blocks: time_blocks} ->
      Enum.filter(time_blocks, fn block ->
        block.is_booked
      end)
      |> Enum.count() > 0
    end)
    |> Enum.count() > 0
  end

  defp calculate_break_blocks(booking_event, date) do
    case booking_event.dates |> Enum.find(&(&1.date == date)) do
      %{time_blocks: time_blocks} ->
        Enum.reduce(time_blocks, 0, fn block, acc ->
          if block.is_break do
            acc + 1
          else
            acc
          end
        end)

      _ ->
        0
    end
  end

  defp calculate_hidden_blocks(booking_event, date) do
    case booking_event.dates |> Enum.find(&(&1.date == date)) do
      %{time_blocks: time_blocks} ->
        Enum.reduce(time_blocks, 0, fn block, acc ->
          if block.is_hidden do
            acc + 1
          else
            acc
          end
        end)

      _ ->
        0
    end
  end

  defp calculate_booked_slots(_booking_event, nil), do: 0

  defp calculate_booked_slots(booking_event, date) do
    case booking_event.dates |> Enum.find(&(&1.date == date)) do
      %{time_blocks: _time_blocks} ->
        times = BookingEvents.available_times(booking_event, date)
        count_booked_slots(times)

      _ ->
        0
    end
  end

  defp count_booked_slots(times) do
    Enum.reduce(times, 0, fn {_time, is_available, is_break, _is_hidden}, acc ->
      if !is_break and !is_available do
        acc + 1
      else
        acc
      end
    end)
  end

  defp is_checked(id, package) do
    if id do
      id == if(is_binary(id), do: package.id |> Integer.to_string(), else: package.id)
    else
      false
    end
  end

  defp get_is_break!(changeset, date_index, time_block_index) do
    dates =
      changeset
      |> Ecto.Changeset.get_field(:dates)
      |> Enum.map(&Map.from_struct/1)

    date = dates |> Enum.at(date_index)
    Enum.at(date.time_blocks, time_block_index).is_break
  end

  defp get_is_hidden!(changeset, date_index, time_block_index) do
    dates =
      changeset
      |> Ecto.Changeset.get_field(:dates)
      |> Enum.map(&Map.from_struct/1)

    date = dates |> Enum.at(date_index)
    Enum.at(date.time_blocks, time_block_index).is_hidden
  end

  defp is_date_booked(event_form, date) do
    event = current(event_form)

    case event.dates |> Enum.find(&(&1.date == date)) do
      %{time_blocks: time_blocks} ->
        Enum.any?(time_blocks, fn %{is_booked: is_booked} ->
          is_booked
        end)

      _ ->
        false
    end
  end

  defp convert_bool(value), do: String.to_atom(value)

  defp convert_dates(dates) do
    dates
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {date_map, idx}, acc ->
      date_str = date_map.date
      time_blocks = update_time_block(date_map.time_blocks)
      acc |> Map.put(to_string(idx), %{"date" => date_str, "time_blocks" => time_blocks})
    end)
  end

  defp update_time_block(time_blocks) do
    Enum.reduce(time_blocks, %{}, fn time_block, time_acc ->
      time_block = get_map_time_block(time_block)
      output = Map.new(time_block, fn {k, v} -> {to_string(k), v} end)

      map_time =
        output
        |> Map.put("end_time", time_parse(time_block.end_time))
        |> Map.put("start_time", time_parse(time_block.start_time))

      time_acc |> Map.put(to_string(Enum.count(time_acc)), map_time)
    end)
  end

  defp get_map_time_block(%Picsello.BookingEvent.TimeBlock{} = time_block),
    do: Map.from_struct(time_block)

  defp get_map_time_block(time_block), do: time_block

  defp time_parse(nil), do: ""
  defp time_parse(time), do: "#{formatted_time(time.hour)}:#{formatted_time(time.minute)}"
  defp formatted_time(time), do: time |> to_string |> String.pad_leading(2, "0")
end
