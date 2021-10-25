defmodule PicselloWeb.PhotoUploadLive.Index do
  @moduledoc false
  use PicselloWeb, :live_view
  
  @app :picsello
  @upload_options [
    accept: ~w(.jpg .jpeg .png),
    max_entries: 50,
    max_file_size: 104_857_600,
    auto_upload: true
  ]
  
  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:uploaded_files, [])
     |> assign(:gcp_credentials, gcp_credentials())
     |> allow_upload(:photo, Keyword.put(@upload_options, :external, &presign_entry/2))}
  end
  
  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    IO.inspect ref
    {:noreply, cancel_upload(socket, :photo, ref)}
  end

  @impl true
  def handle_event("save", params, socket) do
    IO.inspect "save"
    IO.inspect params
    IO.inspect socket
    uploads =
      consume_uploaded_entries(socket, :photo, fn meta, _entry ->
        sign_opts = [bucket: meta[:fields]["bucket"], key: meta[:key]]
        GCSSign.sign_url_v4(socket.assigns.gcp_credentials, sign_opts)
      end)
    
    socket = update(socket, :uploaded_files, &(&1 ++ uploads))
    IO.inspect socket
    {:noreply, socket}
  end

  @bucket "picsello-staging"
  defp presign_entry(entry, socket) do
    uploads = socket.assigns.uploaded_files
    key = entry.client_name
    
    sign_opts = [
      expires_in: 600,
      bucket: @bucket,
      key: key,
      fields: %{
        "content-type" => entry.client_type,
        "cache-control" => "public, max-age=@upload_options"
      },
      conditions: [["content-length-range", 0, 104_857_600]]
    ]
    {:ok, params} = GCSSign.sign_post_policy_v4(socket.assigns.gcp_credentials, sign_opts)
    meta = %{uploader: "GCS", key: key, url: params[:url], fields: params[:fields]}
    IO.inspect meta
    {:ok, meta, socket}
  end

  defp gcp_credentials do
    Application.get_env(:gcs_sign, :gcp_credentials) 
    |> File.read!
    |> Jason.decode!
  end
end

