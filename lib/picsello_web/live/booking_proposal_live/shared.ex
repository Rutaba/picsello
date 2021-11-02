defmodule PicselloWeb.BookingProposalLive.Shared do
  @moduledoc false
  use Phoenix.Component
  alias Picsello.Job

  def banner(assigns) do
    ~H"""
    <h1 class="mb-4 text-3xl font-bold"><%= @title %></h1>

    <div class="py-4 bg-blue-planning-100 modal-banner">
      <div class="text-2xl font-bold text-blue-planning-300">
        <h2><%= Job.name @job %> Shoot <%= @package.name %></h2>
      </div>

      <%= render_slot @inner_block%>
    </div>
    """
  end
end
