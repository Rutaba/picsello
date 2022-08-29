defmodule PicselloWeb.UploaderCache do
  @moduledoc false

  def current_uploaders() do
    ConCache.size(:cache)
  end

  def get(key) do
    case ConCache.get(:cache, key) do
      nil -> []
      values -> values
    end
  end

  def put(key, value) do
    ConCache.put(:cache, key, value)
  end

  def update(key, value) do
    ConCache.update(:cache, key, fn _ -> {:ok, value} end)
  end

  def delete(key) do
    ConCache.delete(:cache, key)
  end

  def delete(key, value) do
    case Enum.filter(get(key), fn {pid, gallery_id, _} ->
           Process.alive?(pid) && gallery_id != value
         end) do
      [] -> ConCache.delete(:cache, key)
      values -> update(key, values)
    end
  end
end
