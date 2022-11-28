defmodule Picsello.Workers.PackDigitals do
  @moduledoc "Background job to create zip of digitals"

  use Oban.Worker,
    unique: [states: ~w[available scheduled executing retryable]a, fields: [:args, :worker]]

  alias Picsello.{Galleries, Galleries.Gallery, Orders, Cart.Order, Pack, Repo}
  import Ecto.Query, only: [from: 2]

  def perform(%Oban.Job{args: args}) do
    packable = to_packable(args)

    broadcast(packable, :ok, %{packable: packable, status: :uploading})

    case Pack.upload(packable) do
      {:ok, url} ->
        broadcast(packable, :ok, %{packable: packable, status: {:ready, url}})

        maybe_notify(packable, url)

        :ok

      {:error, :empty} ->
        # ignore when there are no photos to pack
        :ok

      error ->
        broadcast(packable, :error, %{packable: packable, error: error})
        {:error, error}
    end
  end

  def enqueue(%{id: id, __struct__: packable}, opts \\ []) do
    %{id: id, packable: packable}
    |> __MODULE__.new(opts)
    |> Oban.insert()
  end

  def cancel(%{id: id, __struct__: module}) do
    from(job in Oban.Job,
      where:
        fragment("? -> ?", job.args, "packable") == ^module and
          fragment("? -> ?", job.args, "id") == ^id
    )
    |> Repo.one()
    |> case do
      %{id: job_id} ->
        Oban.cancel_job(job_id)
        :ok

      nil ->
        :ok
    end
  end

  def broadcast(packable, status, payload) do
    context_module(packable).broadcast(
      packable,
      {:pack, status, Map.put(payload, :packable, packable)}
    )
  end

  defp maybe_notify(%Gallery{} = gallery, url) do
    if bundle_purchased?(gallery) do
      Picsello.Notifiers.ClientNotifier.deliver_download_ready(
        gallery,
        url,
        PicselloWeb.Helpers
      )
    end
  end

  defp maybe_notify(_, _), do: nil

  defp to_packable(%{"packable" => module_name, "id" => id}),
    do: module_name |> String.to_existing_atom() |> Repo.get!(id)

  defp context_module(%Order{}), do: Orders
  defp context_module(%Gallery{}), do: Galleries

  defdelegate bundle_purchased?(gallery), to: Picsello.Orders
end
