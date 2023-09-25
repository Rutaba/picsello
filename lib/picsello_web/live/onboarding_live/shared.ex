defmodule PicselloWeb.OnboardingLive.Shared do
  @moduledoc false

  use Phoenix.Component
  use Phoenix.HTML

  alias PicselloWeb.Router.Helpers, as: Routes

  import PicselloWeb.LiveHelpers,
    only: [
      icon: 1
    ]

  def signup_deal(assigns) do
    assigns =
      Enum.into(assigns, %{
        original_price: nil,
        price: nil,
        expires_at: nil
      })

    ~H"""
      <div>
        <div class="bg-base-200 flex justify-center p-8">
          <h3 class="text-4xl text-purple-marketing-300">
            <%= if @original_price do %>
              <strike class="font-bold"><%= @original_price %></strike>
            <% end %>
            <%= @price %>
          </h3>
        </div>
        <%= if @expires_at do %>
          <div class="border flex justify-center p-2 text-purple-marketing-300 font-light tracking-wider text-lg">
            <h4>DEAL EXPIRES IN <%= @expires_at %></h4>
          </div>
        <% end %>
      </div>
    """
  end

  def signup_container(assigns) do
    assigns =
      Enum.into(assigns, %{
        bg_color: "bg-purple-marketing-300",
        show_logout?: false,
        step: nil,
        step_total: nil,
        step_title: nil
      })

    ~H"""
      <div class="min-h-screen container mx-auto">
        <div class="py-10 flex items-center justify-center">
          <.icon name="logo-shoot-higher" class="w-32 h-12 sm:h-20 sm:w-48" />
        </div>
        <div class="grid sm:grid-cols-2 bg-white rounded-lg">
          <div class={"p-10 sm:rounded-l-lg #{@bg_color}"}>
            <%= render_slot(@inner_block) %>
          </div>
          <div class="p-10">
            <%= if @step && @step_total do %>
              <div class="text-sm font-bold text-gray-500">
                <%= @step %> / <%= @step_total %>
              </div>
            <% end %>
            <%= if @step_title do %>
              <h1 class="text-3xl font-bold sm:leading-tight mt-2 mb-4"><%= @step_title %></h1>
            <% end %>
            <%= render_slot(@right_panel) %>
          </div>
        </div>
        <%= if @show_logout? do %>
          <div class="flex items-center justify-center mt-8">
            <%= link("Logout", to: Routes.user_session_path(@socket, :delete), method: :delete) %>
          </div>
        <% end %>
      </div>
    """
  end
end
