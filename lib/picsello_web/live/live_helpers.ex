defmodule PicselloWeb.LiveHelpers do
  @moduledoc "used in both views and components"
  use Phoenix.Component

  import Phoenix.LiveView, only: [assign: 2]
  import PicselloWeb.Router.Helpers, only: [static_path: 2]

  def open_modal(socket, component, assigns \\ %{})

  # main process, modal pid is assigned
  def open_modal(
        %{assigns: %{modal_pid: modal_pid} = parent_assigns} = socket,
        component,
        %{assigns: assigns} = config
      )
      when is_pid(modal_pid) do
    send(
      modal_pid,
      {:modal, :open, component,
       config
       |> Map.put(
         :assigns,
         assigns
         |> Map.merge(Map.take(parent_assigns, [:live_action]))
       )}
    )

    socket
  end

  # called with raw assigns map
  def open_modal(
        %{assigns: %{modal_pid: modal_pid}} = socket,
        component,
        assigns
      )
      when is_pid(modal_pid),
      do: socket |> open_modal(component, %{assigns: assigns})

  # modal process
  def open_modal(
        %{view: PicselloWeb.LiveModal} = socket,
        component,
        config
      ),
      do: socket |> assign(modal_pid: self()) |> open_modal(component, config)

  # main process, before modal pid is assigned
  def open_modal(
        socket,
        component,
        config
      ) do
    socket
    |> assign(queued_modal: {component, config})
  end

  # close from main process
  def close_modal(%{assigns: %{modal_pid: modal_pid}} = socket) do
    send(modal_pid, {:modal, :close})

    socket
  end

  # close from within modal process
  def close_modal(socket) do
    send(self(), {:modal, :close})

    socket
  end

  def strftime("" <> time_zone, time, format) do
    time
    |> DateTime.shift_zone!(time_zone)
    |> Calendar.strftime(format)
  end

  def status_badge(%{job_status: %{current_status: status, is_lead: is_lead}} = assigns) do
    label =
      case {is_lead, status} do
        {false, :archived} ->
          "Archived"

        {false, _} ->
          "Active"

        {true, :not_sent} ->
          "Created"

        {true, :sent} ->
          "Awaiting Acceptance"

        {true, :accepted} ->
          "Awaiting Contract"

        {true, :signed_with_questionnaire} ->
          "Awaiting Questionnaire"

        {true, status} when status in [:signed_without_questionnaire, :answered] ->
          "Awaiting Payment"

        {_, status} ->
          status |> Phoenix.Naming.humanize()
      end

    color_style =
      if status == :archived,
        do: "bg-gray-200",
        else: "bg-blue-light-primary text-blue-primary group-hover:bg-white"

    assigns =
      assigns
      |> Enum.into(%{
        label: label,
        color_style: color_style,
        class: ""
      })

    ~H"""
    <span class={"px-2 py-0.5 text-xs font-semibold rounded #{@color_style} #{@class}"} >
      <%= @label %>
    </span>
    """
  end

  def icon(%{name: name} = assigns) do
    assigns =
      assigns
      |> Enum.into(%{
        width: nil,
        height: nil,
        class: nil,
        path:
          assigns
          |> Map.get(:socket, PicselloWeb.Endpoint)
          |> static_path("/images/icons.svg#" <> name)
      })

    ~H"""
    <svg width={@width} height={@height} class={@class}>
      <use xlink:href={@path} />
    </svg>
    """
  end

  def ok(socket), do: {:ok, socket}
  def noreply(socket), do: {:noreply, socket}
end
