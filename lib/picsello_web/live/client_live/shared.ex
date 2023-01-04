defmodule PicselloWeb.Live.ClientLive.Shared do
  @moduledoc false
  use Phoenix.{HTML, Component}
  import PicselloWeb.LiveHelpers
  alias PicselloWeb.Router.Helpers, as: Routes

  def header(assigns) do
    ~H"""
      <header>
        <div class="center-container p-6 pt-10">
          <div class="flex content-center justify-between md:flex-row">
            <div class="flex-col">
              <.crumbs>
                <:crumb to={Routes.clients_path(@socket, :index)}>
                  All Clients
                </:crumb>
                <:crumb><%= if @client.name, do: @client.name, else: @client.email %></:crumb>
              </.crumbs>
              <h1 {testid("client-details-name")} class="text-4xl font-bold center-container">
                <p class="font-bold">Client: <span class="font-normal"><%= if @client.name, do: @client.name, else: @client.email %></span></p>
              </h1>
            </div>
              <div class="fixed bottom-0 left-0 right-0 z-10 flex flex-shrink-0 w-full sm:p-0 p-6 mt-auto sm:mt-0 sm:bottom-auto sm:static sm:items-start sm:w-auto">
                  <a title="import job" class="w-full md:w-auto btn-primary text-center" phx-click="import-job" phx-value-id={@client.id}>
                      Import job
                  </a>
              </div>
          </div>
        </div>
      </header>
    """
  end
end
