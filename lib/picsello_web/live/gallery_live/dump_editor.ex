defmodule PicselloWeb.GalleryLive.DumpEditor do
  @moduledoc "Temporary page to dump client selections in a whcc editor"
  use PicselloWeb, live_view: [layout: "live_client"]

  alias Picsello.Galleries

  @impl true
  def mount(%{"editorId" => editor_id, "hash" => hash}, _session, socket) do
    account_id =
      hash
      |> Galleries.get_gallery_by_hash()
      |> Galleries.account_id()

    data =
      account_id
      |> Picsello.WHCC.Client.editor_details(editor_id)

    socket
    |> assign(data: data)
    |> ok()
  end

  @impl true
  def render(assigns) do
    ~H"""
      <h1>Editor selections</h1>
      <pre><%= inspect(@data, pretty: true, limit: :infinity, width: 120) %></pre>
    """
  end
end
