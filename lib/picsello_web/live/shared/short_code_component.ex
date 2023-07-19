defmodule PicselloWeb.Shared.ShortCodeComponent do
  @moduledoc """
    Helper functions to use the Short Codes
  """
  use PicselloWeb, :live_component
  import Phoenix.HTML

  @defaults %{
    id: nil,
    show_variables: false,
    variables_list:  [
      %{
        name: "{{client_total}}",
        description: "Let your client know who you are and what makes your business special"
      },
      %{
        name: "{{invoice_total}}",
        description: "The total of invoice"
      },
      %{
        name: "{{invoice_name}}",
        description: "This is the name of invoice"
      },
      %{
        name: "{{order_subtotal}}",
        description: "this is subtotal"
      }
    ]
  }

  @impl true
  def render(assigns) do
    assigns =
      for {k, v} <- @defaults, reduce: assigns do
        acc -> assign_new(acc, k, fn -> v end)
      end
      ~H"""
        <div>
          <div class="flex items-center font-bold bg-gray-100 rounded-t-lg border-gray-200 text-blue-planning-300 p-2.5">
            <.icon name="vertical-list" class="w-4 h-4 mr-2 text-blue-planning-300" />
            Email Variables

            <a href="#" phx-click="toggle-variables" phx-value-show-variables={"#{@show_variables}"} title="close" class="ml-auto cursor-pointer">
              <.icon name="close-x" class="w-3 h-3 stroke-current text-base-300 stroke-2" />
            </a>
          </div>
          <div class="flex flex-col p-2.5 border border-gray-200 rounded-b-lg h-72 overflow-auto">
            <p class="text-base-250">Copy & paste the variable to use in your email. If you remove a variable, the information won’t be inserted.</p>
            <hr class="my-3" />
            <%= for variable <- @variables_list do%>
              <div class="flex-col flex mb-3">
                <span class="flex">
                  <%= variable.name %>
                  <.icon name="trash" class="w-3 h-3 ml-auto text-blue-planning-300"/>
                </span>
                <span class="text-base-250"><%= variable.description %></span>
              </div>
            <% end %>
          </div>
        </div>
      """
  end

  def short_codes_select(assigns) do
    ~H"""
    <.live_component module={__MODULE__} id={assigns[:id]} {assigns} />
    """
  end

  @impl true
  def handle_event("toggle-variables", %{"show-variables" => show_variables}, socket) do
    socket
    |> assign(show_variables: !String.to_atom(show_variables))
    |> noreply()
  end

  defp make_variables() do
    [
      %{
        name: "{{client_total}}",
        description: "Let your client know who you are and what makes your business special"
      },
      %{
        name: "{{invoice_total}}",
        description: "The total of invoice"
      },
      %{
        name: "{{invoice_name}}",
        description: "This is the name of invoice"
      },
      %{
        name: "{{order_subtotal}}",
        description: "this is subtotal"
      }
    ]
  end
end
