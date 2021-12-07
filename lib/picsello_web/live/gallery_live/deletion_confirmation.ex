defmodule PicselloWeb.GalleryLive.DeletionConfirmation do
  @moduledoc """
  The pop-up to confirm deletions. Can be extended. 
  Required options: 
    * :subject -> atom 
    * :confirmation_topic -> atom
    * :cancelation_topic -> atom

  Optional options: 
    * :payload -> map
  """
  use PicselloWeb, :live_component

  def preload([%{subject: subject, payload: %{gallery_name: name}} = assigns])
      when subject in [:photo, :cover_photo] do
    [
      assigns
      |> Map.put(:title, "Delete this photo?")
      |> Map.put(:text, "Are you sure you wish to permanently delete this photo from #{name} ?")
    ]
  end

  def preload([%{subject: :watermark} = assigns]) do
    [
      assigns
      |> Map.put(:title, "Delete watermark?")
      |> Map.put(:text, "Are you sure you wish to permanently delete your
      custom watermark? You can always add another
      one later.
      ")
    ]
  end

  def handle_event("confirm", _, socket) do
    socket |> confirm() |> noreply()
  end

  def handle_event("cancel", _, socket) do
    socket |> cancel() |> noreply
  end

  defp confirm(%{assigns: %{confirmation_topic: topic} = assigns} = socket) do
    send(self(), {topic, assigns[:payload]})

    socket
  end

  defp cancel(%{assigns: %{cancelation_topic: topic}} = socket) do
    send(self(), topic)

    socket
  end
end
