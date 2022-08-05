defmodule PicselloWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use PicselloWeb, :controller
      use PicselloWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller(_) do
    quote do
      use Phoenix.Controller, namespace: PicselloWeb

      import Plug.Conn
      import PicselloWeb.Gettext
      alias PicselloWeb.Router.Helpers, as: Routes
      alias PicselloWeb.ErrorView
    end
  end

  def view(_) do
    quote do
      use Phoenix.View,
        root: "lib/picsello_web/templates",
        namespace: PicselloWeb

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      # Include shared imports and aliases for views
      unquote(view_helpers())
    end
  end

  def live_view(options) do
    options =
      case Keyword.get(options, :layout, "live") do
        false -> []
        name -> [layout: {PicselloWeb.LayoutView, "#{name}.html"}]
      end

    quote do
      use Phoenix.LiveView, unquote(options)

      import PicselloWeb.{LiveViewHelpers, LiveHelpers}

      unquote(view_helpers())
      unquote(modal_helpers())
      unquote(gallery_helpers())
    end
  end

  def live_component(_) do
    quote do
      use Phoenix.LiveComponent
      import PicselloWeb.LiveHelpers

      unquote(view_helpers())
    end
  end

  def router(_) do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel(_) do
    quote do
      use Phoenix.Channel
      import PicselloWeb.Gettext
    end
  end

  defp view_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      # Import LiveView helpers (live_render, live_component, live_patch, etc)
      import Phoenix.LiveView.Helpers

      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import PicselloWeb.FormHelpers
      import PicselloWeb.Gettext
      alias PicselloWeb.Router.Helpers, as: Routes
    end
  end

  defp modal_helpers do
    quote do
      @impl true
      def handle_info(
            {:modal_pid, pid},
            %{assigns: %{queued_modal: {component, config}}} = socket
          ),
          do:
            socket
            |> assign(modal_pid: pid, queued_modal: nil)
            |> open_modal(component, config)
            |> noreply()

      @impl true
      def handle_info({:modal_pid, pid}, socket),
        do:
          socket
          |> assign(modal_pid: pid)
          |> noreply()
    end
  end

  defp gallery_helpers do
    quote do
      @impl true
      def handle_info(
            {:photo_upload_completed,
             %{gallery_id: gallery_id, success_message: success_message}},
            %{assigns: %{current_user: user}} = socket
          ) do
        PicselloWeb.Cache.delete(user.id, gallery_id)
        PicselloWeb.Cache.delete("total-progress-#{gallery_id}")

        socket
        |> assign(galleries_count: length(PicselloWeb.Cache.get(user.id)))
        |> put_flash(:success, success_message)
        |> noreply()
      end

      @impl true
      def handle_info(
            {:galleries_progress, %{total_progress: total_progress, gallery_id: gallery_id}},
            %{assigns: %{current_user: user}} = socket
          ) do
        PicselloWeb.Cache.update("total-progress-#{gallery_id}", total_progress)

        gallery_ids = PicselloWeb.Cache.get(user.id)

        sum =
          Enum.reduce(gallery_ids, 0, fn gallery_id, acc ->
            PicselloWeb.Cache.get("total-progress-#{gallery_id}") + acc
          end)

        accumulated_progress = Float.ceil(sum / Enum.count(gallery_ids))

        accumulated_progress >= 100 &&
          Enum.each(gallery_ids, &PicselloWeb.Cache.delete(user.id, &1))

        socket
        |> assign(:accumulated_progress, accumulated_progress)
        |> noreply()
      end
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [[]])
  end

  defmacro __using__([{which, opts}]) do
    apply(__MODULE__, which, [opts])
  end
end
