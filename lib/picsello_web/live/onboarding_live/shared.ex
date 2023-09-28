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
      <div class="bg-white">
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
        left_classes: "p-8 bg-purple-marketing-300 text-white",
        show_logout?: false,
        right_classes: "p-8",
        step: nil,
        step_total: nil,
        step_title: nil
      })

    ~H"""
      <div class="min-h-screen md:max-w-6xl container mx-auto">
        <div class="py-8 flex items-center justify-center">
          <.icon name="logo-shoot-higher" class="w-32 h-12 sm:h-20 sm:w-48" />
        </div>
        <div class="grid sm:grid-cols-2 bg-white rounded-lg">
          <div class={"order-2 sm:order-1 sm:rounded-l-lg #{@left_classes}"}>
            <%= render_slot(@inner_block) %>
          </div>
          <div class={"#{@right_classes} order-1 sm:order-2 flex flex-col"}>
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
          <div class="flex items-center justify-center my-8">
            <%= link("Logout", to: Routes.user_session_path(@socket, :delete), method: :delete) %>
          </div>
        <% end %>
      </div>
    """
  end
end
