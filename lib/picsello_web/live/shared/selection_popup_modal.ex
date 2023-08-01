defmodule PicselloWeb.Shared.SelectionPopupModal do
  @moduledoc false

  use PicselloWeb, :live_component

  import PicselloWeb.LiveModal, only: [close_x: 1]
  import PicselloWeb.Live.Shared, only: [step_number: 2, client_name_box: 1, heading_subtitle: 1]

  @default_assigns %{
    btn_one_label: "Next",
    btn_two_label: "Next",
    btn_one_event: "",
    btn_two_event: "",
    btn_one_class: "btn-primary",
    btn_two_class: "btn-secondary",
    btn_one_value: nil,
    btn_two_value: nil,
    icon_one: "",
    icon_two: "",
    heading: "",
    title_one: "",
    title_two: "",
    subtitle_one: nil,
    subtitle_two: nil,
    step: nil,
    steps: nil,
    searched_client: nil,
    selected_client: nil
  }

  @impl true
  def update(assigns, socket) do
    socket
    |> assign(Enum.into(assigns, @default_assigns))
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
      <div class="modal">
        <.render_modal
          step={@step}
          steps={@steps}
          searched_client={@searched_client}
          selected_client={@selected_client}
          myself={@myself}
          heading={@heading}
          title_one={@title_one}
          subtitle_one={@subtitle_one}
          icon_one={@icon_one}
          btn_one_label={@btn_one_label}
          btn_one_class={@btn_one_class}
          btn_one_event={@btn_one_event}
          title_two={@title_two}
          subtitle_two={@subtitle_two}
          icon_two={@icon_two}
          btn_two_label={@btn_two_label}
          btn_two_class={@btn_two_class}
          btn_two_event={@btn_two_event}
        />
      </div>
    """
  end

  @impl true
  def handle_event(event, %{}, %{assigns: %{parent_pid: parent_pid, payload: payload}} = socket) do
    send(parent_pid, {:confirm_event, event, payload})

    socket |> noreply()
  end

  @impl true
  def handle_event(event, %{}, %{assigns: %{parent_pid: parent_pid}} = socket) do
    send(parent_pid, {:confirm_event, event})

    socket |> noreply()
  end

  @spec open(Phoenix.LiveView.Socket.t(), %{
          optional(:title_one) => String.t(),
          optional(:title_two) => String.t(),
          optional(:subtitle_one) => String.t(),
          optional(:subtitle_two) => String.t(),
          optional(:btn_one_label) => String.t(),
          optional(:btn_one_event) => any,
          optional(:btn_one_class) => String.t(),
          optional(:btn_two_label) => String.t(),
          optional(:btn_two_event) => any,
          optional(:btn_two_class) => String.t(),
          optional(:icon_one) => String.t() | nil,
          optional(:icon_two) => String.t() | nil,
          optional(:payload) => map,
          heading: String.t()
        }) :: Phoenix.LiveView.Socket.t()
  def open(socket, assigns) do
    socket
    |> open_modal(__MODULE__, assigns)
  end

  def render_modal(assigns) do
    assigns = Enum.into(assigns, @default_assigns)

    ~H"""
      <.close_x />

      <div class="flex flex-col md:flex-row">
        <%= if !is_nil(@step) and !is_nil(@steps) do %>
          <a {if step_number(@step, @steps) > 1, do: %{phx_click: "back", phx_target: @myself, title: "back"}, else: %{}} class="flex w-full md:w-auto">
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

          <%= if step_number(@step, @steps) > 2 && @heading == "Import Existing Job:" do%>
            <.client_name_box searched_client={@searched_client} selected_client={@selected_client} assigns={assigns} />
          <% end %>
        <% end %>
      </div>

      <h1 class="mt-2 mb-4 text-s md:text-3xl">
        <strong class="font-bold"><%= @heading %></strong>
        <%= heading_subtitle(@step) %>
      </h1>

      <.step {assigns} />
    """
  end

  def step(%{step: step} = assigns) when step in [:get_started, :choose_type, nil] do
    assigns = Enum.into(assigns, %{class: "dialog"})

    ~H"""
      <div class="flex mt-8 overflow-hidden border rounded-lg border-base-200">
        <div class="w-4 border-r border-base-200 bg-blue-planning-300" />

        <div class="flex flex-col items-start w-full p-6 sm:flex-row">
          <div class="flex">
            <.icon name={@icon_one} class="w-12 h-12 mt-2 text-blue-planning-300" />
            <h1 class="mt-2 ml-4 text-2xl font-bold sm:hidden"><%= @title_one %></h1>
          </div>
          <div class="flex flex-col sm:ml-4">
            <h1 class="hidden text-2xl font-bold sm:block"><%= @title_one %></h1>

            <p class="max-w-xl mt-1 mr-2"><%= @subtitle_one %></p>
          </div>

          <button type="button" class={"self-center w-full px-8 mt-6 ml-auto #{@btn_one_class} sm:w-auto sm:mt-0"} phx-value-type={@btn_one_value} phx-click={@btn_one_event} phx-target={@myself}><%= @btn_one_label %></button>
        </div>
      </div>
      <div class="flex mt-6 overflow-hidden border rounded-lg border-base-200">
        <div class="w-4 border-r border-base-200 bg-base-200" />

        <div class="flex flex-col items-start w-full p-6 sm:flex-row">
          <div class="flex">
            <.icon name={@icon_two} class="w-12 h-12 mt-2 text-blue-planning-300" />
            <h1 class="mt-2 ml-4 text-2xl font-bold sm:hidden"><%= @title_two %></h1>
          </div>
          <div class="flex flex-col sm:ml-4">
            <h1 class="hidden text-2xl font-bold sm:block"><%= @title_two %></h1>

            <p class="max-w-xl mt-1 mr-2"><%= @subtitle_two %></p>
          </div>
          <button type="button" class={"self-center w-full px-8 mt-6 ml-auto #{@btn_two_class} sm:w-auto sm:mt-0"} phx-value-type={@btn_two_value} phx-click={@btn_two_event} phx-target={@myself}><%= @btn_two_label %></button>
        </div>
      </div>
    """
  end

  def step(assigns) when assigns.step in [:job_details, :package_payment, :invoice, :documents] do
    PicselloWeb.JobLive.ImportWizard.step(assigns)
  end

  def step(assigns) when assigns.step in [:details, :pricing] do
    PicselloWeb.GalleryLive.CreateComponent.step(assigns)
  end
end
