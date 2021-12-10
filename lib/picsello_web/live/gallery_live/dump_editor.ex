defmodule PicselloWeb.GalleryLive.DumpEditor do
  @moduledoc "Temporary page to dump client selections in a whcc editor"
  use PicselloWeb, live_view: [layout: "live_client"]

  @impl true
  def mount(%{"editorId" => editor_id}, _session, socket) do
    data = Picsello.WHCC.Client.editor_details(editor_id)

    socket
    |> assign(data: data)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
      <h1>Editor selections</h1>
      <b>Product Id: </b> <%= @data["productId"] %>
      <pre><%= inspect(@data["selections"], pretty: true, limit: :infinity, width: 120) %></pre>
      <hr>
      <pre><%= inspect(@data, pretty: true) %></pre>
    """
  end
end
