defmodule Picsello.Galleries.Workers.PhotoStorage do
  @moduledoc """
  Manages URL signing to store photos on GCS
  """
  @callback path_to_url(String.t()) :: String.t()
  @callback path_to_url(String.t(), String.t()) :: String.t()
  @callback params_for_upload(keyword()) :: map()
  @callback delete(String.t()) :: atom()
  @callback delete(String.t(), String.t()) :: atom()

  def impl, do: Application.get_env(:picsello, :photo_storage_service)

  def path_to_url(path), do: impl().path_to_url(path)
  def path_to_url(path, bucket), do: impl().path_to_url(path, bucket)
  def delete(path), do: impl().delete(path)
  def delete(path, bucket), do: impl().delete(path, bucket)
  def params_for_upload(opts), do: impl().params_for_upload(opts)
end
