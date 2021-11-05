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
            entries: %{}

  @upload_factor 0.77

  def add_entry(%__MODULE__{} = progress, entry) do
    put_in(progress, [:entries, entry.uuid], new_entry(entry))
  end

  def remove_entry(%__MODULE__{} = progress, entry) do
    photo_id =
      progress.photo_entries
      |> Enum.find_value(fn {k, v} -> if v == entry.uuid, do: k end)

    progress
    |> put_in([:photo_entries], progress.photo_entries |> Map.delete(photo_id))
    |> put_in([:entries], progress.entries |> Map.delete(entry.uuid))
  end

  def complete_upload(%__MODULE__{} = progress, entry) do
    put_in(progress, [:entries, entry.uuid, :is_uploaded], true)
  end

  def link_photo(%__MODULE__{} = progress, entry, photo_id) do
    put_in(progress, [:photo_entries, photo_id], entry.uuid)
  end

  def complete_processing(%__MODULE__{} = progress, photo_id) do
    case progress.photo_entries[photo_id] do
      nil -> progress
      uuid -> put_in(progress, [:entries, uuid, :is_processed], true)
    end
  end

  def progress_for_entry(%__MODULE__{} = progress, entry) do
    cond do
      progress.entries[entry.uuid].is_processed -> 100
      progress.entries[entry.uuid].is_uploaded -> 100 * @upload_factor
      true -> entry.progress
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

  defp new_entry(_entry),
    do: %{
      is_uploaded: false,
      is_processed: false
    }
end
