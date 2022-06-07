defmodule Picsello.ObanLogger do
  @moduledoc false
  require Logger

  def handle_event([:oban, :job, :start], measure, meta, _) do
    Logger.warn("[Oban] start #{meta.worker} at #{measure.system_time}")
  end

  def handle_event(
        [:oban, :job, :exception],
        _,
        %{kind: kind, worker: worker} = meta,
        _
      ) do
    details = Exception.format(kind, Map.get(meta, :reason), Map.get(meta, :stacktrace, []))
    Logger.error("[Oban] #{kind} #{worker}\n#{details}")
  end

  def handle_event([:oban, :job, event], measure, meta, _) do
    Logger.warn("[Oban] #{event} #{meta.worker} ran in #{measure.duration}")
  end
end
