defmodule PicselloWeb.PackageLive.Shared do
  @moduledoc """
  handlers used by both package and package templates
  """
  alias Picsello.{
    Package
  }

  import PicselloWeb.Gettext, only: [dyn_gettext: 1]
  use Phoenix.HTML
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

        <p class="mb-2 line-clamp-2"><%= raw @package.description %></p>

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

  def quill_input(assigns) do
    html_field = assigns |> Map.get(:html_field)
    text_field = assigns |> Map.get(:text_field)

    ~H"""
    <div class="col-span-2">
      <div id="editor-wrapper" phx-hook="Quill" phx-update="ignore" class="mt-2" data-placeholder={assigns |> Map.get(:placeholder)}
         data-html-field-name={input_name(@f, html_field)} data-text-field-name={input_name(@f, text_field)}>
        <div id="toolbar" class="bg-blue-planning-100 text-blue-planning-300">
          <button class="ql-bold"></button>
          <button class="ql-italic"></button>
          <button class="ql-underline"></button>
          <button class="ql-list" value="bullet"></button>
          <button class="ql-list" value="ordered"></button>
          <button class="ql-link"></button>
        </div>
        <div id="editor" style={assigns |> Map.get(:style)}> </div>
          <%= if (html_field), do: hidden_input @f, html_field, phx_debounce: "500" %>
          <%= if (text_field), do: hidden_input @f, text_field, phx_debounce: "500" %>
        </div>
      </div>
    """
  end
end
