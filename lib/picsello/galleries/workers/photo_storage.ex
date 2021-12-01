defmodule Picsello.Galleries.Workers.PhotoStorage do
  @moduledoc """
  Manages URL signing to store photos on GCS
  """

  @bucket Application.compile_env(:picsello, :photo_storage_bucket)

  def path_to_url(path, bucket \\ @bucket) when is_binary(path) do
    sign_opts = [bucket: bucket, key: path]
    GCSSign.sign_url_v4(gcp_credentials(), sign_opts)
  end

  def params_for_upload(options) do
    {:ok, params} = GCSSign.sign_post_policy_v4(gcp_credentials(), options)
    params
  end

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
