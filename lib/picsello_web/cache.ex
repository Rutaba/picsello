defmodule PicselloWeb.Cache do
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
    case List.delete(get(key), value) do
      [] -> ConCache.delete(:cache, key)
      values -> ConCache.put(:cache, key, values)
    end
  end
end
