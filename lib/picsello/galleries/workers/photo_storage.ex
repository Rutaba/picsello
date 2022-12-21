defmodule Picsello.Galleries.Workers.PhotoStorage do
  @moduledoc """
  Manages URL signing to store photos on GCS
  """
  @callback path_to_url(String.t()) :: String.t()
  @callback path_to_url(String.t(), String.t()) :: String.t()
  @callback params_for_upload(keyword()) :: map()
  @callback delete(String.t()) :: :ok | :error
  @callback delete(String.t(), String.t()) :: :ok | :error

  @callback get(String.t()) :: {:ok, GoogleApi.Storage.V1.Model.Object.t()} | {:error, any()}
  @callback get(String.t(), String.t()) ::
              {:ok, GoogleApi.Storage.V1.Model.Object.t()} | {:error, any()}

  @callback initiate_resumable(String.t(), map()) :: {:ok | :error, Tesla.Env.t()}
  @callback continue_resumable(String.t(), any(), Keyword.t()) :: {:ok | :error, Tesla.Env.t()}

  def impl, do: Application.get_env(:picsello, :photo_storage_service)

  def path_to_url(path), do: impl().path_to_url(path)
  def path_to_url(path, bucket), do: impl().path_to_url(path, bucket)
  def delete(path), do: impl().delete(path)
  def delete(path, bucket), do: impl().delete(path, bucket)

  def get(path), do: impl().get(path)
  def get(path, bucket), do: impl().get(path, bucket)
  def initiate_resumable(path, metadata), do: impl().initiate_resumable(path, metadata)

  def continue_resumable(location, chunk, opts),
    do: impl().continue_resumable(location, chunk, opts)

  def params_for_upload(opts), do: impl().params_for_upload(opts)
  def insert(path, object), do: impl().insert(path, object)
end
