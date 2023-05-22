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
    case Enum.filter(get(key), fn {pid, _, _} ->
           is_pid(pid) && Process.alive?(pid)
         end) do
      [] -> ConCache.delete(:cache, key)
      values -> update(key, values)
    end
  end
end
