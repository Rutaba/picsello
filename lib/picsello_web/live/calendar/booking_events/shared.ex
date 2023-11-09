defmodule PicselloWeb.Calendar.BookingEvents.Shared do
  @moduledoc "shared functions for booking events"
  use Phoenix.HTML
  use Phoenix.Component
  require Logger

  import Phoenix.LiveView
  import PicselloWeb.LiveHelpers
  import PicselloWeb.Gettext, only: [ngettext: 3]
  import PicselloWeb.Live.Shared, only: [make_popup: 2]
  import PicselloWeb.Helpers, only: [job_url: 1]
  import PicselloWeb.GalleryLive.Shared, only: [add_message_and_notify: 3]

  alias PicselloWeb.{
    SearchComponent,
    ConfirmationComponent,
    ClientMessageComponent,
    Shared.SelectionPopupModal,
    PackageLive.WizardComponent,
    Live.Calendar.BookingEvents.Index
  }

  alias Picsello.{
    Repo,
    Utils,
    Client,
    Clients,
    Package,
    BookingEvent,
    BookingEvents,
    BookingProposal,
    BookingEventDate,
    BookingEventDates,
    BookingEventDate.SlotBlock
  }

  alias Ecto.Multi
  alias PicselloWeb.Router.Helpers, as: Routes

  def handle_event(
        "duplicate-event",
        params,
        %{assigns: %{current_user: %{organization_id: org_id}}} = socket
      ) do
    BookingEvents.duplicate_booking_event(fetch_booking_event_id(params, socket), org_id)
    |> case do
      {:ok, %{duplicate_booking_event: new_event}} ->
        socket
        |> redirect(to: "/booking-events/#{new_event.id}")

      {:error, :duplicate_booking_event, _, _} ->
        socket
        |> put_flash(:error, "Unable to duplicate event")

      _ ->
        socket
        |> put_flash(:error, "Unexpected error")
    end
    |> noreply()
  end

  def handle_event("new-event", %{}, socket),
    do:
      socket
      |> SelectionPopupModal.open(%{
        heading: "Create a Booking Event",
        title_one: "Single Event",
        subtitle_one: "Best for a single weekend or a few days you’d like to fill.",
        icon_one: "calendar-add",
        btn_one_event: "create-single-event",
        title_two: "Repeating Event",
        subtitle_two:
          "Best for an event you’d like to run every week, weekend, every month, etc.",
        icon_two: "calendar-repeat",
        btn_two_event: "create-repeating-event"
      })
      |> noreply()

  def handle_event("confirm-archive-event", params, socket) do
    socket
    |> ConfirmationComponent.open(%{
      title: "Are you sure?",
      subtitle: """
      Are you sure you want to archive this event?
      """,
      confirm_event: "archive_event_#{fetch_booking_event_id(params, socket)}",
      confirm_label: "Yes, archive",
      close_label: "Cancel",
      icon: "warning-orange"
    })
    |> noreply()
  end

  def handle_event("confirm-disable-event", params, socket) do
    socket
    |> ConfirmationComponent.open(%{
      title: "Disable this event?",
      subtitle: """
      Disabling this event will hide all availability for this event and prevent any further booking. This is also the first step to take if you need to cancel an event for any reason.
      Some things to keep in mind:
        • If you are no longer able to shoot at the date and time provided, let your clients know. We suggest offering them a new link to book with once you reschedule!
        • You may need to refund any payments made to prevent confusion with your clients.
        • Archive each job individually in the Jobs page if you intend to cancel it.
        • Reschedule if possible to keep business coming in!
      """,
      confirm_event: "disable_event_#{fetch_booking_event_id(params, socket)}",
      confirm_label: "Disable Event",
      close_label: "Cancel",
      icon: "warning-orange"
    })
    |> noreply()
  end

  def handle_event(
        "enable-event",
        params,
        %{assigns: %{current_user: %{organization: organization}}} = socket
      ) do
    params
    |> fetch_booking_event_id(socket)
    |> BookingEvents.enable_booking_event(organization.id)
    |> case do
      {:ok, _event} ->
        socket
        |> assign_events()
        |> put_flash(:success, "Event enabled successfully")

      {:error, _} ->
        socket
        |> put_flash(:success, "Error enabling event")
    end
    |> noreply()
  end

  def handle_event(
        "unarchive-event",
        params,
        %{assigns: %{current_user: %{organization: organization}}} = socket
      ) do
    params
    |> fetch_booking_event_id(socket)
    |> BookingEvents.enable_booking_event(organization.id)
    |> case do
      {:ok, _event} ->
        socket
        |> assign_events()
        |> put_flash(:success, "Event unarchive successfully")

      {:error, _} ->
        socket
        |> put_flash(:success, "Error unarchiving event")
    end
    |> noreply()
  end

  def handle_event("confirm-delete-date", _params, socket) do
    socket
    |> ConfirmationComponent.open(%{
      title: "Are you sure?",
      subtitle: "Are you sure you want to delete this date?",
      confirm_event: "delete_date",
      confirm_label: "Yes, delete",
      close_label: "Cancel",
      icon: "warning-orange"
    })
  end

  def handle_event(
        "confirm-cancel-session",
        %{
          "booking-event-date-id" => booking_event_date_id,
          "slot-index" => slot_index
        },
        socket
      ) do
    socket
    |> ConfirmationComponent.open(%{
      title: "Cancel session?",
      subtitle:
        "Are you sure you want to cancel this session? You'll have to refund them through Stripe or whatever payment method you use previously",
      confirm_event: "cancel_session",
      confirm_label: "Yes, cancel",
      close_label: "No, go back",
      icon: "warning-orange",
      payload: %{
        booking_event_date_id: String.to_integer(booking_event_date_id),
        slot_index: String.to_integer(slot_index),
        slot_update_args: %{status: :open, client_id: nil, job_id: nil}
      }
    })
    |> noreply()
  end

  def handle_event(
        "confirm-reschedule",
        %{
          "booking-event-date-id" => booking_event_date_id,
          "slot-client-id" => slot_client_id,
          "slot-index" => slot_index
        },
        %{assigns: %{current_user: current_user, booking_event: booking_event}} = socket
      ) do
    [booking_event_date_id, slot_client_id, slot_index] =
      to_integer([booking_event_date_id, slot_client_id, slot_index])

    booking_event_dates = get_booking_date(booking_event, booking_event_date_id)

    filtered_slots =
      booking_event_dates.slots
      |> Enum.filter(&(&1.status == :open))
      |> Enum.with_index(fn slot, slot_index ->
        {"#{slot.slot_start} - #{slot.slot_end}", slot_index}
      end)

    socket
    |> make_popup(
      icon: nil,
      dropdown?: true,
      close_label: "Cancel",
      class: "dialog",
      title: "Reschedule session",
      confirm_label: "Reschedule",
      confirm_class: "btn-primary",
      dropdown_items: filtered_slots,
      dropdown_label: "Pick a new time",
      confirm_event: "reschedule_session",
      payload: %{
        booking_event_date_id: booking_event_date_id,
        slot_index: slot_index,
        slot_client_id: slot_client_id,
        client_name: slot_client_name(current_user, slot_client_id),
        client_icon: "client-icon"
      }
    )
  end

  def handle_event(
        "confirm-mark-hide",
        %{"booking-event-date-id" => booking_event_date_id, "slot-index" => slot_index},
        socket
      ) do
    socket
    |> ConfirmationComponent.open(%{
      title: "Mark block hidden?",
      subtitle:
        "This is useful if you'd like to give yourself a break or make yourself look booked at this time and open it up later",
      confirm_event: "change_slot_status",
      confirm_class: "btn-primary",
      confirm_label: "Hide block",
      close_label: "Cancel",
      icon: nil,
      payload: %{
        booking_event_date_id: to_integer(booking_event_date_id),
        slot_index: to_integer(slot_index),
        slot_update_args: %{status: :hidden}
      }
    })
    |> noreply()
  end

  def handle_event(
        "confirm-mark-open",
        %{"booking-event-date-id" => booking_event_date_id, "slot-index" => slot_index},
        socket
      ) do
    socket
    |> ConfirmationComponent.open(%{
      title: "Mark block open?",
      subtitle: "Are you sure you to allow this block to be bookable by clients?",
      confirm_event: "change_slot_status",
      confirm_class: "btn-primary",
      confirm_label: "Show block",
      close_label: "Cancel",
      icon: nil,
      payload: %{
        booking_event_date_id: String.to_integer(booking_event_date_id),
        slot_index: String.to_integer(slot_index),
        slot_update_args: %{status: :open, client_id: nil}
      }
    })
    |> noreply()
  end

  def handle_event("open-client", params, socket) do
    params
    |> Map.get("slot-client-id", nil)
    |> case do
      nil ->
        socket
        |> put_flash(:error, "Unable to open the client")

      client_id ->
        socket
        |> redirect(to: "/clients/#{to_integer(client_id)}")
    end
    |> noreply()
  end

  def handle_event(
        "open-job",
        params,
        socket
      ) do
    params
    |> Map.get("slot-job-id", nil)
    |> case do
      nil ->
        socket
        |> put_flash(:error, "There is no job assigned. Please set a job first.")

      job_id ->
        socket
        |> redirect(to: "/leads/#{to_integer(job_id)}")
    end
    |> noreply()
  end

  def handle_event(
        "confirm-reserve",
        %{"booking-event-date-id" => booking_event_date_id, "slot-index" => slot_index},
        %{assigns: %{current_user: current_user, booking_event: booking_event}} = socket
      ) do
    [booking_event_date_id, slot_index] = to_integer([booking_event_date_id, slot_index])

    booking_event_date = get_booking_date(booking_event, booking_event_date_id)
    slot = Enum.at(booking_event_date.slots, slot_index)
    clients = Clients.find_all_by(user: current_user)

    socket
    |> assign(:clients, clients)
    |> SearchComponent.open(%{
      change_event: :change_client,
      submit_event: :reserve_session,
      save_label: "Reserve",
      title: "Reserve session",
      icon: "clock",
      placeholder: "Search clients by email or first/last name…",
      empty_result_description: "No client found with that information",
      component_used_for: :booking_events_search,
      payload: %{
        clients: clients,
        booking_event: booking_event,
        booking_event_date: booking_event_date,
        slot_index: slot_index,
        slot: slot
      }
    })
    |> noreply()
  end

  def handle_event(
        "send-email",
        %{"id" => date_id},
        socket
      ),
      do:
        socket
        |> open_compose(to_integer(date_id))

  def handle_event(
        "send-email",
        %{},
        socket
      ),
      do:
        socket
        |> open_compose()

  def handle_info(
        {:confirm_event, event},
        %{assigns: %{current_user: %{organization_id: organization_id}}} = socket
      )
      when event in ["create-repeating-event", "create-single-event"] do
    case BookingEvents.create_booking_event(%{
           organization_id: organization_id,
           is_repeating: event == "create-repeating-event",
           name: "New event"
         }) do
      {:ok, booking_event} ->
        socket
        |> redirect(to: "/booking-events/#{booking_event.id}")

      {:error, _} ->
        socket
        |> put_flash(:error, "Unable to create booking event")
    end
    |> noreply()
  end

  def handle_info(
        {:update_templates, %{templates: templates}},
        %{assigns: %{modal_pid: modal_pid}} = socket
      ) do
    send_update(modal_pid, WizardComponent, id: WizardComponent, templates: templates)

    socket
    |> noreply()
  end

  def handle_info(
        {:confirm_event, "confirm_duplicate_event",
         %{booking_event_id: event_id, organization_id: org_id}},
        socket
      ) do
    duplicate_booking_event =
      BookingEvents.get_booking_event!(
        org_id,
        event_id
      )
      |> Repo.preload([:dates])
      |> Map.put(:status, :active)
      |> Map.from_struct()

    duplicate_event_dates =
      duplicate_booking_event
      |> Map.get(:dates, nil)
      |> Enum.map(fn t ->
        t
        |> Map.replace(:date, nil)
        |> Map.replace(:slots, edit_slots_status(t))
      end)

    multi =
      Multi.new()
      |> Multi.insert(
        :duplicate_booking_event,
        BookingEvent.duplicate_changeset(duplicate_booking_event)
      )

    duplicate_event_dates
    |> Enum.with_index()
    |> Enum.reduce(multi, fn {event_date, i}, multi ->
      multi
      |> Multi.insert(
        "duplicate_booking_event_date_#{i}",
        fn %{duplicate_booking_event: event} ->
          BookingEventDate.changeset(%{
            booking_event_id: event.id,
            location: event_date.location,
            address: event_date.address,
            session_length: event_date.session_length,
            session_gap: event_date.session_gap,
            time_blocks: BookingEvents.to_map(event_date.time_blocks),
            slots: BookingEvents.to_map(event_date.slots)
          })
        end
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{duplicate_booking_event: new_event}} ->
        socket
        |> redirect(to: "/booking-events/#{new_event.id}")

      {:error, :duplicate_booking_event, _, _} ->
        socket
        |> put_flash(:error, "Unable to duplicate event")

      _ ->
        socket
        |> put_flash(:error, "Unexpected error")
    end
    |> noreply()
  end

  def handle_info(
        {:confirm_event, "change_slot_status",
         %{
           booking_event_date_id: booking_event_date_id,
           slot_index: slot_index,
           slot_update_args: slot_update_args
         }},
        socket
      ) do
    case BookingEventDates.update_slot_status(booking_event_date_id, slot_index, slot_update_args) do
      {:ok, _booking_event_date} ->
        socket
        |> assign_events()
        |> put_flash(:success, "Slot changed successfully")

      {:error, _} ->
        socket
        |> put_flash(:error, "Error changing slot status")
    end
    |> close_modal()
    |> noreply()
  end

  def handle_info({:confirm_event, "delete_date"}, socket) do
    socket |> close_modal() |> noreply()
  end

  def handle_info(
        {:confirm_event, "reschedule_session",
         %{
           booking_event_date_id: booking_event_date_id,
           item_id: item_id,
           slot_client_id: slot_client_id,
           slot_index: slot_index
         }},
        %{assigns: %{current_user: user, booking_event: booking_event}} = socket
      ) do
    booking_event_date = get_booking_date(booking_event, to_integer(booking_event_date_id))

    slot =
      booking_event_date.slots
      |> Enum.at(slot_index)

    new_slot =
      booking_event_date
      |> BookingEventDates.available_slots(booking_event)
      |> Enum.at(to_integer(item_id))

    {_slot, new_slot_index} =
      booking_event_date.slots
      |> Enum.with_index(fn slot, slot_index -> {slot, slot_index} end)
      |> Enum.filter(fn {slot, _slot_index} ->
        slot.slot_start == new_slot.slot_start && slot.slot_end == new_slot.slot_end
      end)
      |> hd()

    with %Client{name: name, email: email} <- slot_client(user, slot_client_id),
         {:ok, %{proposal: proposal, shoot: shoot, job: job}} <-
           BookingEvents.save_booking(
             booking_event,
             booking_event_date,
             %{
               name: name,
               email: email,
               phone: nil,
               date: booking_event_date.date,
               time: slot.slot_start
             },
             %{slot_index: new_slot_index, slot_status: :reserved}
           ),
         {:ok, _} <-
           BookingEvents.expire_booking(%{
             "id" => slot.job_id,
             "booking_date_id" => booking_event_date.id,
             "slot_index" => slot_index
           }) do
      Picsello.Shoots.broadcast_shoot_change(shoot)
      class = "underline text-blue-planning-300"

      socket
      |> assign_events()
      |> make_popup(
        icon: nil,
        title: "Reschedule Session",
        subtitle: """
          Great! Session has been rescheduled and a <a class="#{class}" href="#{job_url(job.id)}" target="_blank">job</a> + <a class="#{class}" href="#{BookingProposal.url(proposal.id)}" target="_blank">client portal</a> has been created for you to share
        """,
        copy_btn_label: "Copy link, I’ll send separately",
        copy_btn_event: "copy-link",
        copy_btn_value: BookingProposal.url(proposal.id),
        confirm_event: "finish-proposal",
        confirm_class: "btn-primary",
        confirm_label: "Send client link via email",
        show_search: false,
        close_label: "Close",
        payload: %{
          client_name: name,
          client_icon: "client-icon",
          job: Picsello.Jobs.get_job_by_id(job.id),
          proposal: proposal
        }
      )
    else
      {:error, _} ->
        socket
        |> put_flash(:error, "Booking cannot be rescheduled, please try again")
        |> close_modal()
        |> noreply()

      e ->
        Logger.warning("[save_booking] error: #{inspect(e)}")

        socket
        |> put_flash(:error, "Couldn't reschedule this booking")
        |> close_modal()
        |> noreply()
    end
  end

  def handle_info(
        {:confirm_event, "cancel_session",
         %{
           booking_event_date_id: booking_event_date_id,
           slot_index: slot_index
         }},
        %{assigns: %{booking_event: booking_event}} = socket
      ) do
    booking_event_date = get_booking_date(booking_event, to_integer(booking_event_date_id))
    slot = Enum.at(booking_event_date.slots, slot_index)

    case BookingEvents.expire_booking(%{
           "id" => slot.job_id,
           "booking_date_id" => booking_event_date_id,
           "slot_index" => slot_index
         }) do
      {:ok, _} ->
        socket
        |> assign_events()
        |> put_flash(:success, "Session cancelled successfully!")

      {:error, _} ->
        socket
        |> put_flash(:error, "Error changing slot status")
    end
    |> close_modal()
    |> noreply()
  end

  def handle_info(
        {:confirm_event, "disable_event_" <> id},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    case BookingEvents.disable_booking_event(id, current_user.organization_id) do
      {:ok, _event} ->
        socket
        |> assign_events()
        |> put_flash(:success, "Event disabled successfully")

      {:error, _} ->
        socket
        |> put_flash(:success, "Error disabling event")
    end
    |> close_modal()
    |> noreply()
  end

  def handle_info(
        {:confirm_event, "archive_event_" <> id},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    case BookingEvents.archive_booking_event(id, current_user.organization_id) do
      {:ok, _event} ->
        socket
        |> assign_events()
        |> put_flash(:success, "Event archive successfully")

      {:error, _} ->
        socket
        |> put_flash(:success, "Error archiving event")
    end
    |> close_modal()
    |> noreply()
  end

  def handle_info(
        {:search_event, :change_client, search},
        %{assigns: %{modal_pid: modal_pid, clients: clients}} = socket
      ) do
    send_update(modal_pid, SearchComponent,
      id: SearchComponent,
      results:
        Clients.search(search, clients) |> Enum.map(&%{id: &1.id, name: &1.name, email: &1.email}),
      search: search,
      selection: nil
    )

    socket
    |> noreply
  end

  def handle_info(
        {:search_event, :reserve_session, client,
         %{
           slot_index: slot_index,
           slot: slot,
           booking_event_date: booking_event_date,
           booking_event: booking_event
         }},
        %{assigns: %{current_user: _current_user}} = socket
      ) do
    {:ok, %{proposal: proposal, shoot: shoot, job: job}} =
      BookingEvents.save_booking(
        booking_event,
        booking_event_date,
        %{
          name: client.name,
          email: client.email,
          phone: nil,
          date: booking_event_date.date,
          time: slot.slot_start
        },
        %{slot_index: slot_index, slot_status: :reserved}
      )

    Picsello.Shoots.broadcast_shoot_change(shoot)
    class = "underline text-blue-planning-300"

    socket
    |> assign_events()
    |> make_popup(
      icon: nil,
      title: "Reserve Session",
      subtitle: """
        Great! Session has been reserved and a <a class="#{class}" href="#{job_url(job.id)}" target="_blank">job</a> + <a class="#{class}" href="#{BookingProposal.url(proposal.id)}" target="_blank">client portal</a> has been created for you to share
      """,
      copy_btn_label: "Copy link, I’ll send separately",
      copy_btn_event: "copy-link",
      copy_btn_value: BookingProposal.url(proposal.id),
      confirm_event: "finish-proposal",
      confirm_class: "btn-primary",
      confirm_label: "Send client link via email",
      show_search: false,
      close_label: "Cancel",
      payload: %{
        job: Picsello.Jobs.get_job_by_id(job.id),
        proposal: proposal,
        client_name: client.name,
        client_icon: "client-icon",
        booking_event_date_id: booking_event_date.id
      }
    )
  end

  def handle_info(
        {:confirm_event, "finish-proposal", %{job: job}},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    %{body_template: body_html, subject_template: subject} =
      case Picsello.EmailPresets.for(job, :booking_proposal) do
        [preset | _] ->
          Picsello.EmailPresets.resolve_variables(
            preset,
            {job},
            PicselloWeb.Helpers
          )

        _ ->
          Logger.warning("No booking proposal email preset for #{job.type}")
          %{body_template: "", subject_template: ""}
      end

    socket
    |> assign(:job, job)
    |> ClientMessageComponent.open(%{
      composed_event: :proposal_message_composed,
      current_user: current_user,
      enable_size: true,
      enable_image: true,
      presets: [],
      body_html: body_html,
      subject: subject,
      client: Picsello.Job.client(job)
    })
    |> noreply()
  end

  def handle_info({:message_composed, message_changeset, recipients}, socket) do
    add_message_and_notify(socket, message_changeset, recipients)
  end

  defdelegate handle_info(message, socket), to: PicselloWeb.LeadLive.Show

  def overlap_time?(blocks), do: BookingEvents.overlap_time?(blocks)

  @doc """
  Edits the status of booking event date slots.

  This function takes a list of booking event date slots and edits their status. It iterates through each slot
  in the list and sets the status to either `:hidden` or `:open` based on the existing status. If the current
  status is `:hidden`, it remains unchanged; otherwise, it is updated to `:open`. This function is typically
  used to toggle the visibility of slots.

  ## Parameters

  - `slots` ([SlotBlock.t()]): A list of booking event date slots to edit.

  ## Returns

  A list of updated booking event date slots with modified status.

  ## Example

  ```elixir
  # Edit the status of booking event date slots
  iex> slots = [SlotBlock.t(), SlotBlock.t()]
  iex> edit_slots_status(%{slots: slots})
  [SlotBlock.t(), SlotBlock.t()]

  ## Notes

  This function is useful for modifying the status of booking event date slots, typically used to control their visibility
  """
  @spec edit_slots_status(map()) :: [SlotBlock.t()]
  def edit_slots_status(%{slots: slots}) do
    Enum.map(slots, fn s ->
      if s.status == :hidden, do: %{s | status: :hidden}, else: %{s | status: :open}
    end)
  end

  @spec update_slots_for_edit(map()) :: [SlotBlock.t()]
  def update_slots_for_edit(%{slots: slots}) do
    Enum.map(slots, fn s ->
      if s.status == :hidden, do: %{s | is_hide: true}, else: s
    end)
  end

  def assign_events(
        %{assigns: %{booking_event: %{id: event_id}, current_user: %{organization: organization}}} =
          socket
      ) do
    %{package_template: package_template} =
      booking_event =
      organization.id
      |> BookingEvents.get_booking_event!(event_id)
      |> BookingEvents.preload_booking_event()
      |> put_url_booking_event(organization, socket)

    calendar_date_event =
      case booking_event do
        %{dates: []} -> nil
        %{dates: [date | _]} -> date
      end

    socket
    |> assign(:booking_event, booking_event)
    |> assign(:package, package_template)
    |> assign(:payments_description, payments_description(booking_event))
    |> assign(:calendar_date_event, calendar_date_event)
  end

  def assign_events(%{assigns: %{booking_events: _booking_events}} = socket),
    do: Index.assign_booking_events(socket)

  def convert_date_string_to_date(nil), do: nil
  def convert_date_string_to_date(date), do: Date.from_iso8601!(date)

  def get_date(%{"date" => date}), do: date
  def get_date(%{date: date}), do: date

  def count_booked_slots(slot),
    do: Enum.count(slot, fn s -> s.status in [:booked, :reserved] end)

  def count_available_slots(slot), do: Enum.count(slot, fn s -> s.status == :open end)
  def count_hidden_slots(slot), do: Enum.count(slot, fn s -> s.status == :hidden end)

  # tells us if the created/duplicated booking event is complete or not
  # if we dont have dates or a package_template_id, then its incomplete
  # similarly its complete if both dates and package_template_id exist
  def incomplete_status?(%{package_template_id: nil}), do: true
  def incomplete_status?(%{dates: []}), do: true
  def incomplete_status?(_), do: false

  # will be true if the status matches in the array <status_list>
  def disabled?(booking_event, status_list), do: booking_event.status in status_list

  def put_url_booking_event(booking_event, organization, socket),
    do:
      booking_event
      |> Map.put(
        :url,
        Routes.client_booking_event_url(
          socket,
          :show,
          organization.slug,
          booking_event.id
        )
      )

  def get_booking_date(booking_event, date_id),
    do:
      booking_event.dates
      |> Enum.filter(fn date -> date.id == date_id end)
      |> hd()

  def get_booking_event_clients(booking_event, nil),
    do:
      booking_event.dates
      |> Enum.map(fn date ->
        get_clients(date)
      end)
      |> List.flatten()

  def get_booking_event_clients(booking_event, date_id),
    do:
      booking_event.dates
      |> Enum.filter(fn date -> date.id == date_id end)
      |> hd()
      |> get_clients()

  def slot_client(user, slot_client_id) do
    Clients.get_client(user, id: slot_client_id)
  end

  def slot_client_name(user, slot_client_id) do
    case slot_client(user, slot_client_id) do
      nil ->
        "Not found"

      client ->
        client
        |> Map.get(:name)
        |> Utils.capitalize_all_words()
    end
  end

  defp open_compose(
         %{assigns: %{current_user: current_user, booking_event: booking_event}} = socket,
         date_id \\ nil
       ) do
    clients = get_booking_event_clients(booking_event, date_id)

    recipients =
      cond do
        Enum.any?(clients) && length(clients) > 1 ->
          %{"to" => clients |> hd(), "bcc" => tl(clients)}

        Enum.any?(clients) ->
          %{"to" => clients}

        true ->
          %{"to" => ""}
      end

    socket
    |> ClientMessageComponent.open(%{
      current_user: current_user,
      modal_title: "Send booking event email",
      show_client_email: true,
      show_subject: true,
      presets: [],
      send_button: "Send",
      recipients: recipients
    })
    |> noreply()
  end

  defp get_clients(date) do
    date
    |> Map.get(:slots)
    |> Enum.filter(fn slot -> Map.get(slot, :client) end)
    |> Enum.reduce([], fn slot, acc -> [slot.client.email | acc] end)
  end

  # to cater different handle_event and info calls
  # if we get booking-event-id in params (1st argument) it returns the id
  # otherwise get the id from socket
  defp fetch_booking_event_id(%{"event-id" => id}, _assigns), do: id

  defp fetch_booking_event_id(%{}, %{assigns: %{booking_event: booking_event}}),
    do: booking_event.id

  defp payments_description(%{package_template: nil}), do: nil

  defp payments_description(%{
         package_template: %{package_payment_schedules: package_payment_schedules} = package
       }) do
    currency_symbol = Money.Currency.symbol!(package.currency)
    total_price = Package.price(package)
    {first_payment, remaining_payments} = package_payment_schedules |> List.pop_at(0)

    payment_count = Enum.count(remaining_payments)

    count_text =
      if payment_count > 0,
        do: ngettext(", 1 other payment", ", %{count} other payments", payment_count),
        else: nil

    if first_payment do
      interval_text =
        if first_payment.interval do
          "#{first_payment.due_interval}"
        else
          "#{first_payment.count_interval} #{first_payment.time_interval} #{first_payment.shoot_interval}"
        end

      if first_payment.percentage do
        amount = (total_price.amount / 10_000 * first_payment.percentage) |> Kernel.trunc()
        "#{currency_symbol}#{amount}.00 #{interval_text}"
      else
        "#{first_payment.price} #{interval_text}"
      end <> "#{count_text}"
    else
      nil
    end
  end
end
