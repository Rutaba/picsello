defmodule Picsello.Galleries.Workers.PhotoStorage.Impl do
  @moduledoc false

  alias Picsello.Galleries.Workers.PhotoStorage
  @behaviour PhotoStorage

  @bucket Application.compile_env(:picsello, :photo_storage_bucket)

  @impl PhotoStorage
  def path_to_url(path, bucket \\ @bucket) do
    sign_opts = [bucket: bucket, key: path, expires_in: 604_800]
    GCSSign.sign_url_v4(gcp_credentials(), sign_opts)
  end

  @impl PhotoStorage
  def params_for_upload(options) do
    {:ok, params} = GCSSign.sign_post_policy_v4(gcp_credentials(), options)
    params
  end

  @impl PhotoStorage
  def delete(path, bucket \\ @bucket)

  def delete(nil, _), do: :ignored

  def delete(path, bucket) do
    {:ok, token} = Goth.Token.for_scope("https://www.googleapis.com/auth/cloud-platform")

    token.token
    |> GoogleApi.Storage.V1.Connection.new()
    |> GoogleApi.Storage.V1.Api.Objects.storage_objects_delete(bucket, path)
  rescue
    _ -> :ignored
  end

  defp gcp_credentials() do
    {:ok, private_key} = Goth.Config.get("private_key")
    {:ok, client_id} = Goth.Config.get("client_id")

    %{
      "private_key" => private_key,
      "client_id" => client_id
    }
  end
end
