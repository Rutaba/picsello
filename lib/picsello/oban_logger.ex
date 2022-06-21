defmodule Picsello.ObanLogger do
  @moduledoc false
  require Logger

  def handle_event([:oban, :job, :start], measure, meta, _) do
    Logger.warn("[Oban] start #{meta.worker} at #{measure.system_time}")
  end

  def handle_event([:oban, :job, :exception], measure, %{kind: kind, worker: worker} = meta, _) do
    stacktrace = Map.get(meta, :stacktrace, [])

    details = Exception.format(kind, meta.reason, stacktrace)
    Logger.error("[Oban] #{kind} #{worker}\n#{details}")

    extra =
      meta.job
      |> Map.take([:id, :args, :meta, :queue, :worker])
      |> Map.merge(measure)

    Sentry.capture_exception(meta.reason, stacktrace: stacktrace, extra: extra)
  end

  def handle_event([:oban, :job, event], measure, meta, _) do
    Logger.warn("[Oban] #{event} #{meta.worker} ran in #{measure.duration}")
  end
end
