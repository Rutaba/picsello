defmodule Picsello.Orders.Pack do
  @moduledoc """
  context module for creating a zip of an order's digitals
  """

  defmodule IodataStream do
    @moduledoc false

    @doc """
      Streams a `t:Enumerable.t()` of `t:iodata()` into chunks where all but the last one will have a `IO.iodata_length/1` of `size`.
      The last one may be smaller.
    """
    @spec chunk_every(Enumerable.t(), pos_integer()) :: Enumerable.t()
    def chunk_every(stream, size) do
      stream
      |> Stream.map(&to_acc/1)
      |> Stream.concat([:end])
      |> Stream.transform(to_acc([]), transform(size))
    end

    defp transform(size),
      do: fn
        :end, {_acc_size, acc_iodata} ->
          {[acc_iodata], to_acc([])}

        {element_length, iodata}, {acc_length, acc_iodata} ->
          iodata = acc_iodata ++ iodata

          case acc_length + element_length do
            length when length < size ->
              {[], {length, iodata}}

            ^size ->
              {[iodata], to_acc([])}

            length when length > size ->
              {head, rest} = split(iodata, size)
              {chunks, rest} = [rest] |> chunk_every(size) |> Enum.split(-1)
              {[head | chunks], to_acc(rest)}
          end
      end

    @spec split(iodata(), pos_integer()) :: {iodata(), iodata()}
    def split([_ | _] = iodata, size) do
      {{_, head}, rest} =
        for datum <- iodata, reduce: {to_acc([]), []} do
          {{^size, _} = acc, rest} ->
            {acc, [datum | rest]}

          {{acc_length, acc_iodata}, []} ->
            datum_length = IO.iodata_length([datum])
            length = acc_length + datum_length

            if length <= size do
              {{length, [datum | acc_iodata]}, []}
            else
              gap = size - acc_length
              <<head::binary-size(gap), rest::binary>> = IO.iodata_to_binary([datum])

              {{size, [head | acc_iodata]}, [rest]}
            end
        end

      {Enum.reverse(head), Enum.reverse(rest)}
    end

    defp to_acc([]), do: {0, []}
    defp to_acc([_ | _] = iodata), do: {IO.iodata_length(iodata), iodata}
  end

  alias Picsello.{Galleries.Gallery, Orders, Repo, Cart.Order, Galleries.Workers.PhotoStorage}

  @chunk_size Integer.pow(2, 18) *
                trunc(Application.compile_env(:picsello, :chunks_per_request, 32))

  def stream(photos) do
    photos
    |> to_entries()
    |> Packmatic.build_stream()
  end

  @spec url(Order.t() | Gallery.t()) :: {:ok, String.t()} | {:error, any()}
  def url(packable) do
    case packable |> path() |> PhotoStorage.get() do
      {:ok, %{name: name}} -> {:ok, PhotoStorage.path_to_url(name)}
      error -> error
    end
  end

  def path(%Order{gallery: %{name: gallery_name}} = order) do
    Path.join([
      "galleries",
      to_string(order.gallery_id),
      "orders",
      "#{gallery_name} - #{Order.number(order)}.zip"
    ])
  end

  def path(%Gallery{name: gallery_name, id: id}) do
    Path.join([
      "galleries",
      to_string(id),
      "#{gallery_name}.zip"
    ])
  end

  @spec upload(Gallery.t() | Order.t()) :: {:ok, String.t()} | {:error, any()}
  @spec upload(Gallery.t() | Order.t(), Keyword.t()) :: {:ok, String.t()} | {:error, any()}
  def upload(packable, opts \\ [])

  def upload(%Gallery{} = gallery, opts),
    do:
      if(Orders.can_download_all?(gallery),
        do:
          gallery
          |> Ecto.assoc(:photos)
          |> Repo.all()
          |> stream()
          |> do_upload(path(gallery), opts),
        else: {:error, "cannot download all photos in gallery #{gallery.id}"}
      )

  def upload(%Order{id: order_id}, opts) when is_integer(order_id) do
    with %Order{} = order <-
           Orders.client_paid_query() |> Repo.get(order_id) |> Repo.preload(:gallery),
         [_ | _] = photos <-
           order |> Orders.get_order_photos() |> Repo.all() do
      photos |> stream() |> do_upload(path(order), opts)
    else
      nil -> {:error, "no client paid order with id #{order_id}"}
      [] -> {:error, "no photos in order #{order_id}"}
    end
  end

  defp do_upload(stream, path, opts) do
    chunk_size = Keyword.get(opts, :chunk_size, @chunk_size)

    with(
      {:ok, _, _} = acc <- initialize_resumable(path),
      {:ok, _size, _resumable_url} <-
        stream
        |> IodataStream.chunk_every(chunk_size)
        |> Stream.map(&to_sized_binary/1)
        |> Enum.reduce_while(acc, fn chunk, {:ok, first_byte_index, location} ->
          case continue_resumable(location, chunk, first_byte_index, chunk_size) do
            {:ok, last_byte_index} -> {:cont, {:ok, last_byte_index, location}}
            error -> {:halt, error}
          end
        end),
      do: {:ok, path}
    )
  end

  def to_sized_binary(iodata) do
    binary = IO.iodata_to_binary(iodata)

    {byte_size(binary), binary}
  end

  defp continue_resumable(location, {chunk_length, chunk}, first_byte_index, chunk_size) do
    last_byte_index = first_byte_index + chunk_length - 1

    total_size =
      case chunk_length do
        ^chunk_size -> "*"
        _ -> first_byte_index + chunk_length
      end

    location
    |> PhotoStorage.continue_resumable(chunk,
      headers: [
        {"content-length", chunk_length},
        {"content-range", "bytes #{first_byte_index}-#{last_byte_index}/#{total_size}"}
      ]
    )
    |> case do
      {:ok, %{status: status}} when status in [200, 308] -> {:ok, last_byte_index + 1}
      {:error, _} = error -> error
      error -> {:error, error}
    end
  end

  defp initialize_resumable(name) do
    with {:ok, %{headers: headers, status: 200}} <-
           PhotoStorage.initiate_resumable(name, "application/zip"),
         ["" <> location] <- for({"location", location} <- headers, do: location) do
      {:ok, 0, location}
    else
      {:error, _} = error -> error
      error -> {:error, error}
    end
  end

  defp to_entries(photos) do
    photos
    |> Enum.map(fn entry ->
      [source: {:url, PhotoStorage.path_to_url(entry.original_url)}, path: entry.name]
    end)
    |> Enum.group_by(&Keyword.get(&1, :path))
    |> Enum.flat_map(&dublicates(elem(&1, 1)))
  end

  defp dublicates(entries) do
    case entries do
      [_ | [_ | _]] -> annotate(entries)
      _ -> entries
    end
  end

  defp annotate(entries) do
    for {[source: {:url, source}, path: path], index} <- Enum.with_index(entries) do
      path =
        path
        |> Path.split()
        |> List.update_at(-1, fn filename ->
          extname = Path.extname(filename)
          basename = Path.basename(filename, extname)

          "#{basename} (#{index + 1})#{extname}"
        end)
        |> Path.join()

      [source: {:url, source}, path: path]
    end
  end
end
