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
            processing_speed: 50_000

  @upload_factor 0.608

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

  def complete_upload(%__MODULE__{} = progress, entry, now \\ DateTime.utc_now()) do
    %{size: size, uploading_since: since} = progress.entries[entry.uuid]

    new_speed =
      progress.upload_speed
      |> avg_speed_add(
        Enum.count(progress.entries, fn {_, %{is_uploaded: x}} -> x end),
        speed(size, {now, since})
      )

    progress
    |> put_in([:entries, entry.uuid, :is_uploaded], true)
    |> put_in([:entries, entry.uuid, :processing_since], DateTime.utc_now())
    |> put_in([:upload_speed], new_speed)
  end

  def link_photo(%__MODULE__{} = progress, entry, photo_id) do
    put_in(progress, [:photo_entries, photo_id], entry.uuid)
  end

  def complete_processing(%__MODULE__{} = progress, photo_id, now \\ DateTime.utc_now()) do
    case progress.photo_entries[photo_id] do
      nil ->
        progress

      uuid ->
        %{size: size, processing_since: since} = progress.entries[uuid]

        new_speed =
          progress.processing_speed
          |> avg_speed_add(
            Enum.count(progress.entries, fn {_, %{is_processed: x}} -> x end),
            speed(size, {now, since})
          )

        progress
        |> put_in([:entries, uuid, :is_processed], true)
        |> put_in([:processing_speed], new_speed)
    end
  end

  def progress_for_entry(%__MODULE__{} = progress, entry, now \\ DateTime.utc_now()) do
    cond do
      progress.entries[entry.uuid].is_processed ->
        100

      progress.entries[entry.uuid].is_uploaded ->
        passed = DateTime.diff(now, progress.entries[entry.uuid].processing_since, :millisecond)
        part = min(progress.processing_speed * passed / 1000 / entry.client_size, 0.97)
        100 * (@upload_factor + (1 - @upload_factor) * part)

      true ->
        entry.progress * @upload_factor
    end
  end

  def total_progress(%__MODULE__{} = progress) do
    count = Enum.count(progress.entries)

    done =
      progress.entries
      |> Enum.map(fn
        {_, %{is_processed: true}} -> 1
        {_, %{is_uploaded: true}} -> @upload_factor
        _ -> 0
      end)
      |> Enum.sum()

    trunc(100 * done / count)
  end

  def estimate_remaining(progress, now) do
    progress.entries
    |> Enum.map(fn
      {_, %{is_processed: true}} ->
        0

      {_, %{is_uploaded: true, size: size, processing_since: since}} ->
        passed = DateTime.diff(now, since, :millisecond)
        est = size * 1000 / progress.processing_speed
        (est - passed) / 1000

      {_, %{is_uploaded: false, size: size, uploading_since: since}} ->
        passed = DateTime.diff(now, since, :millisecond)
        est = size * 1000 / progress.upload_speed
        est_processing = size / progress.processing_speed
        est_processing + (est - passed) / 1000

      _ ->
        -10_000
    end)
    |> Enum.max()
    |> then(fn
      s when s > 120 -> "#{trunc(s / 60)} minutes"
      s when s < 10 -> "few seconds"
      s -> "#{trunc(s)} seconds"
    end)
  end

  defp speed(size, {now, since}), do: trunc(size * 1000 / DateTime.diff(now, since, :millisecond))

  defp avg_speed_add(old_speed, count, speed),
    do: trunc((old_speed * count + speed) / (count + 1))

  defp new_entry(entry),
    do: %{
      is_uploaded: false,
      is_processed: false,
      uploading_since: DateTime.utc_now(),
      processing_since: nil,
      size: entry.client_size
    }
end
