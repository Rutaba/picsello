defmodule Picsello.Workers.PackPhotos do
  @moduledoc "Background job to create zip of photos"

  use Oban.Worker, unique: [fields: [:args, :worker]]

  alias Picsello.{
    Repo,
    Orders,
    Orders.Pack,
    Notifiers.UserNotifier,
    Galleries.Workers.PhotoStorage
  }

  import Ecto.Query, only: [from: 2]

  def perform(%Oban.Job{args: args}) do
    {photo_ids, _args} = Map.pop(args, "photo_ids")
    {email, _args} = Map.pop(args, "email")
    {gallery_name, _args} = Map.pop(args, "gallery_name")
    {gallery_url, _args} = Map.pop(args, "gallery_url")

    case Pack.upload_photos(photo_ids) do
      {:ok, path} ->
        downlaod_url = PhotoStorage.path_to_url(path)

        UserNotifier.deliver_download_ready_notification(
          %{email: email},
          gallery_name,
          gallery_url,
          downlaod_url
        )

      error ->
        Orders.broadcast("abcd", {:pack, :error, error})
    end
  end

  def executing?(%{id: order_id}) do
    worker = to_string(__MODULE__)

    from(job in Oban.Job,
      where:
        job.worker == ^worker and job.state == "executing" and
          fragment("(? -> 'order_id')::bigint = ?", job.args, ^order_id)
    )
    |> Repo.exists?()
  end
end
