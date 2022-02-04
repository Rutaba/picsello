defmodule Picsello.Galleries.PhotoProcessing.GalleryUploadProgress do
  @moduledoc """
  Manages gallery upload progress

  Currently counts files and receives updates from processing

  Can be improved by
    - adding each entry upload tracking
    - calculating speed of upload
    - calculating speed of processing
    - provide accurate estimate for whole process

  """

  use StructAccess

  defstruct photo_entries: %{},
            entries: %{},
            upload_speed: 100_000,
            processing_speed: 50_000_000_000_000_000_000
            since: nil

  @upload_factor 1

  def add_entry(%__MODULE__{} = progress, entry) do
    put_in(
      progress,
      [:entries, entry.uuid],
      Map.get(progress.entries, entry.uuid, new_entry(entry))
    )
  end

  def remove_entry(%__MODULE__{} = progress, entry) do
    photo_id =
      progress.photo_entries
      |> Enum.find_value(fn {k, v} -> if v == entry.uuid, do: k end)

    progress
    |> put_in([:photo_entries], progress.photo_entries |> Map.delete(photo_id))
    |> put_in([:entries], progress.entries |> Map.delete(entry.uuid))
  end

  def complete_upload(%__MODULE__{} = progress, entry, _now \\ DateTime.utc_now()) do
    progress
    |> put_in([:entries, entry.uuid, :is_uploaded], true)
    |> put_in([:entries, entry.uuid, :progress], 100)
  end

  def track_progress(%__MODULE__{since: nil} = progress, entry) do
    progress
    |> put_in([:since], DateTime.utc_now())
    |> track_progress(entry)
  end

  def track_progress(%__MODULE__{} = progress, entry) do
    progress
    |> put_in([:entries, entry.uuid, :progress], entry.progress)
  end

  def progress_for_entry(%__MODULE__{} = progress, entry) do
    item = get_in(progress, [:entries, entry.uuid])
    (item.is_uploaded && 100) || entry.progress
  end

  def total_progress(%__MODULE__{} = progress) do
    {done, total} = done_total_progress(progress)

    trunc(done * 100 / total)
  end

  defp done_total_progress(progress) do
    progress.entries
    |> Enum.reduce({0, 0}, fn {_, %{size: size, progress: progress}}, {done, total} ->
      {done + size * progress / 100, total + size}
    end)
  end

  def estimate_remaining(%{since: nil}, _), do: "n/a"

  def estimate_remaining(%{since: since} = progress, now) do
    progress
    |> done_total_progress()
    |> then(fn {done, total} -> done / total end)
    |> then(fn
      0.0 ->
        -1

      done ->
        passed = DateTime.diff(now, since, :millisecond) / 1000

        if passed < 3 do
          -1
        else
          (1 - done) * passed / done
        end
    end)
    |> then(fn
      s when s > 3600 -> "#{trunc(s / 360) / 10} hours"
      s when s > 120 -> "#{trunc(s / 60)} minutes"
      s when s < 5 -> "few seconds"
      -1 -> "n/a"
      s -> "#{trunc(s)} seconds"
    end)
  end

  defp new_entry(entry),
    do: %{
      is_uploaded: false,
      size: entry.client_size,
      progress: 0
    }
end
