defmodule LogFormatter do
  @moduledoc """
  An Elixir module for nicely formatted text logs
  """
  @red "\e[0;31m"
  @dark_red "\e[1;31m"
  @black "\e[0;30m"
  @blue "\e[1;34m"
  @green "\e[0;32m"
  @purple "\e[0;35m"
  @cyan "\e[0;36m"
  @space " "
  @eol "\n"
  @spec format(atom, term, Logger.Formatter.time(), keyword()) :: IO.chardata()
  def format(level, message, {_date, timestamp}, metadata) do
    time = Logger.Formatter.format_time(timestamp) |> color(@cyan)
    metadata = Map.new(metadata)
    pid = inspect(metadata.pid) |> String.pad_trailing(15) |> color(@purple)
    mfa = mfa(metadata) |> color(@blue)

    level = level_color(level)
    file_ref = file(metadata)

    [
      time,
      @space,
      pid,
      @space,
      "[",
      level,
      "]",
      @space,
      mfa,
      " - ",
      @green,
      file_ref,
      @black,
      " -> ",
      message,
      @eol
    ]
  end

  defp level_color(level) do
    color =
      case level do
        :debug -> @blue
        :info -> @cyan
        :warn -> @red
        _ -> @dark_red
      end

    level |> to_string() |> color(color)
  end

  @spec color(any, any) :: <<_::56, _::_*8>>
  def color(string, color) do
    "#{color}#{string}#{@black}"
  end

  defp file(%{file: file, line: line}) do
    file = Path.basename(file)
    String.pad_trailing("#{file}:#{line}", 25)
  end

  defp file(_) do
    ""
  end

  defp mfa(%{mfa: {m, f, a}}) do
    m = m |> to_string |> String.replace_prefix("Elixir.", "")
    String.pad_trailing("#{m}.#{f}/#{a}", 52)
  end

  defp mfa(_) do
    ""
  end
end
