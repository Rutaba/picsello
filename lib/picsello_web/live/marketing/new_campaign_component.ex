defmodule PicselloWeb.Live.Marketing.NewCampaignComponent do
  @moduledoc false
  use PicselloWeb, :live_component
  alias Picsello.Marketing
  import PicselloWeb.Shared.Quill, only: [quill_input: 1]

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> assign_segments_count()
    |> then(fn socket ->
      socket
      |> assign_new(:changeset, fn ->
        body = """
        <p>Sometimes your previous and potential clients are just an email away from booking their next session. Reminding them of why they might want new photography and keeping your brand fresh in their mind is a great regular practice to keep your calendar full.</p>
        <p>You don’t have to overthink it, sometimes just a friendly reminder that you exist and are booking shoots is the only push it takes to get some people to book. Other times it’s helpful to incentivize clients to book sooner rather than later. This can be a special offer like mini sessions, or just a reminder that they’ll need to book ahead to be sure you can accommodate them at their preferred time of year.</p>
        <p>Remember, the only marketing email guaranteed to not get you business is the one you don’t send.</p>
        <p>You can send this email with the intent of  promoting upcoming sessions, bringing attention to products you offer, or simply ask for referrals and reviews!</p>
        <p>You can customize your email by changing the font size, using the bold, underline or italics to emphasize a point.</p>
        <p>Bring your email to life by adding an image or a graphic that showcases what you are promoting!</p>
        <p>If you have a scheduler consider hyperlinking your scheduling link here in your email (ours will be coming this summer!)</p>
        <p>Remember you can always review the email before you send it - your email signature will be added so no need to add a signature!</p>
        <p>We hope you have a successful marketing campaign!</p>
        """

        Marketing.new_campaign_changeset(
          %{
            "subject" => "Write a subject line that puts photography on your contacts’ minds.",
            "body_text" => body,
            "body_html" => body,
            "segment_type" => "new"
          },
          socket.assigns.current_user.organization_id
        )
      end)
    end)
    |> assign_new(:review, fn -> false end)
    |> assign_new(:template_preview, fn -> nil end)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal">
      <div class="flex items-start justify-between flex-shrink-0">
        <h1 class="text-3xl font-bold"><%= if @review, do: "Review", else: "Edit" %> email</h1>

        <button phx-click="modal" phx-value-action="close" title="close modal" type="button" class="p-2">
          <.icon name="close-x" class="w-3 h-3 stroke-current stroke-2 sm:stroke-1 sm:w-6 sm:h-6"/>
        </button>
      </div>

      <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" phx-target={@myself}>
        <fieldset class={classes(%{"hidden" => @review})}>
          <%= labeled_input f, :subject, label: "Subject", placeholder: "Type subject…", wrapper_class: "mt-4", phx_debounce: "500" %>

          <%= label_for f, :segment_type, label: "Contact List", class: "block mt-4 pb-2" %>
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <.segment_type_option name={input_name(f, :segment_type)} icon="three-people" value="new" checked={input_value(f, :segment_type) == "new"} title={"Unassigned contacts (#{@segments_count["new"]})"} subtitle="Contacts who aren't assigned to a lead or a job" />
            <.segment_type_option name={input_name(f, :segment_type)} icon="notebook" value="all" checked={input_value(f, :segment_type) == "all"} title={"All contacts (#{@segments_count["all"]})"} subtitle="All contacts in your list" />
          </div>

          <label class="block mt-4 input-label" for="editor">Message</label>

          <.quill_input f={f} html_field={:body_html} text_field={:body_text} placeholder="Start typing…" enable_size={true} enable_image={true} current_user={@current_user} />
        </fieldset>

        <%= if @review do %>
          <div class="mt-3 p-3 rounded-lg border w-full">
            <dl>
              <dt class="inline text-blue-planning-300">Subject line:</dt>
              <dd class="inline"><%= input_value(f, :subject) %></dd>
            </dl>
            <dl>
              <dt class="inline text-blue-planning-300">Recipient list:</dt>
              <dd class="inline"><%= ngettext "1 contact", "%{count} contacts", @current_segment_count %></dd>
            </dl>
          </div>
          <%= case @template_preview do %>
            <% nil -> %>
            <% :loading -> %>
              <div class="flex items-center justify-center w-full mt-10 text-xs">
                <div class="w-3 h-3 mr-2 rounded-full opacity-75 bg-blue-planning-300 animate-ping"></div>
                Loading...
              </div>
            <% content -> %>
              <div class="rounded-lg bg-base-200 flex justify-center mt-4 p-2">
                <iframe srcdoc={content} class="w-[30rem]" scrolling="no" phx-hook="IFrameAutoHeight" id="template-preview">
                </iframe>
              </div>
          <% end %>
        <% end %>

        <PicselloWeb.LiveModal.footer>
          <%= if @review do %>
            <button id="send" class="btn-primary" title="send" type="submit" disabled={!@changeset.valid? || @current_segment_count == 0} phx-disable-with="Send">
              Send
            </button>
            <button id="back" class="btn-secondary" title="back" type="button" phx-click="toggle-review" phx-target={@myself} phx-disable-with="Back">
              Back
            </button>
          <% else %>
            <button id="review" class="btn-primary" title="review" type="button" disabled={!@changeset.valid?} phx-click="toggle-review" phx-target={@myself} phx-disable-with="Review">
              Review
            </button>
          <% end %>
          <button id="close" class="btn-secondary" title="close" type="button" phx-click="modal" phx-value-action="close">
            Close
          </button>

        </PicselloWeb.LiveModal.footer>

      </.form>
    </div>
    """
  end

  defp segment_type_option(assigns) do
    ~H"""
      <label class={classes(
        "flex items-center p-2 border rounded-lg hover:bg-blue-planning-100 hover:bg-opacity-60 cursor-pointer leading-tight",
        %{"border-blue-planning-300 bg-blue-planning-100" => @checked}
      )}>
        <input class="hidden" type={:radio} name={@name} value={@value} checked={@checked} />

        <div class={classes(
          "flex items-center justify-center w-7 h-7 ml-1 mr-3 rounded-full flex-shrink-0",
          %{"bg-blue-planning-300 text-white" => @checked, "bg-base-200" => !@checked}
        )}>
          <.icon name={@icon} class="fill-current" width="14" height="14" />
        </div>

        <div class="flex flex-col">
          <div class="font-semibold text-sm">
            <%= @title %>
          </div>
          <div class="block text-sm opacity-70">
            <%= @subtitle %>
          </div>
        </div>
      </label>
    """
  end

  @impl true
  def handle_event("validate", %{"campaign" => params}, socket) do
    socket |> assign_changeset(params) |> noreply()
  end

  @impl true
  def handle_event(
        "toggle-review",
        _,
        %{assigns: %{review: false, changeset: changeset}} = socket
      ) do
    body_html = Ecto.Changeset.get_field(changeset, :body_html)
    Process.send_after(self(), {:load_template_preview, __MODULE__, body_html}, 50)
    socket |> assign(:review, true) |> assign(:template_preview, :loading) |> noreply()
  end

  @impl true
  def handle_event("toggle-review", _, %{assigns: %{review: true}} = socket) do
    socket |> assign(:review, false) |> noreply()
  end

  @impl true
  def handle_event(
        "save",
        %{"campaign" => params},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    case Marketing.save_new_campaign(params, current_user.organization_id) do
      {:ok, campaign} ->
        send(socket.parent_pid, {:update, campaign})
        socket |> close_modal() |> noreply()

      {:error, :campaign, changeset, _} ->
        socket |> assign(:changeset, changeset) |> noreply()

      {:error, :email, _error, _} ->
        socket |> noreply()
    end
  end

  def assign_changeset(
        %{assigns: %{current_user: current_user, segments_count: segments_count}} = socket,
        params \\ %{},
        action \\ :validate
      ) do
    changeset =
      Marketing.new_campaign_changeset(params, current_user.organization_id)
      |> Map.put(:action, action)

    count = Map.get(segments_count, Ecto.Changeset.get_field(changeset, :segment_type))

    assign(socket, changeset: changeset, current_segment_count: count)
  end

  def assign_segments_count(%{assigns: %{current_user: current_user}} = socket) do
    count = Marketing.segments_count(current_user.organization_id)
    socket |> assign(segments_count: count)
  end

  def open(%{assigns: assigns} = socket),
    do:
      open_modal(
        socket,
        __MODULE__,
        %{
          assigns: Map.take(assigns, [:current_user])
        }
      )
end
