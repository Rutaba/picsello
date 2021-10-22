defmodule ImageProcessing.Tasks do
  @moduledoc """
  Image processing tasks placeholders
  """

  def aspect(str) do
    Process.sleep(Enum.random([1000, 50]))
    str <> ":"
  end

  def preview(str) do
    Process.sleep(1000)
    str <> "."
  end

  def watermark(str) do
    Process.sleep(Enum.random([1000, 500]))
    str <> "_"
  end

  def stringify(x) do
    Integer.to_string(x)
  end
end
