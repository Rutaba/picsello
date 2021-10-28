defmodule PicselloWeb.PackageLive.Shared do
  @moduledoc """
  handlers used by both package and package templates
  """
  alias Picsello.{
    Package
  }

  import PicselloWeb.Gettext, only: [dyn_gettext: 1]
  import Phoenix.LiveView
  use Phoenix.Component

  @spec package_card(%{
          package: %Package{}
        }) :: %Phoenix.LiveView.Rendered{}
  def package_card(assigns) do
    assigns = assigns |> Enum.into(%{class: ""})

    ~H"""
      <div class={"flex flex-col p-4 border rounded cursor-pointer hover:bg-blue-planning-100 hover:border-blue-planning-300 group #{@class}"}>
        <h1 class="text-2xl font-bold line-clamp-2"><%= @package.name %></h1>

        <p class="mb-2 line-clamp-2"><%= @package.description %></p>

        <dl class="flex flex-row-reverse items-center justify-end mt-auto">
          <dt class="ml-2 text-gray-500">Downloadable photos</dt>

          <dd class="flex items-center justify-center w-8 h-8 text-xs font-bold bg-gray-200 rounded-full group-hover:bg-white">
            <%= @package.download_count %>
          </dd>
        </dl>

        <hr class="my-4" />

        <div class="flex items-center justify-between">
          <div class="text-gray-500"><%= dyn_gettext @package.job_type %></div>

          <div class="text-lg font-bold">
            <%= @package |> Package.price() |> Money.to_string(fractional_unit: false) %>
          </div>
        </div>
      </div>
    """
  end
end
