defmodule Picsello.Orders.PackTest do
  use Picsello.DataCase, async: true

  def get_zip_files(target) do
    {:ok, zip_handle} = :zip.zip_open(target)
    {:ok, zip_list} = :zip.zip_list_dir(zip_handle)
    :ok = :zip.zip_close(zip_handle)

    for {:zip_file, name, _, _, _, _} <- zip_list do
      to_string(name)
    end
  end

  def add_digital(order, original_url, name \\ "my photo.png") do
    insert(:digital,
      order: order,
      photo: insert(:photo, name: name, gallery: order.gallery, original_url: original_url)
    )
  end

  describe "upload" do
    setup do
      [
        original_url:
          PicselloWeb.Endpoint.struct_url()
          |> Map.put(:path, PicselloWeb.Endpoint.static_path("/images/phoenix.png"))
          |> URI.to_string()
      ]
    end

    setup %{original_url: original_url} do
      Mox.stub(Picsello.PhotoStorageMock, :path_to_url, fn ^original_url ->
        original_url
      end)

      :ok
    end

    setup do
      [order: :order |> insert(placed_at: DateTime.utc_now()) |> Repo.preload(:gallery)]
    end

    def header(opts, name) do
      [value] = for({^name, value} <- Keyword.get(opts, :headers, []), do: value)
      value
    end

    test "client has not paid - is an error", %{order: order} do
      insert(:digital, order: order)
      insert(:intent, order: order, status: :requires_payment_method)

      assert {:error, "no client paid order" <> _} = Picsello.Orders.Pack.upload(order.id)
    end

    test "no digitals in order - is an error", %{order: order} do
      assert {:error, "no photos in order" <> _} = Picsello.Orders.Pack.upload(order.id)
    end

    test "streams the upload to GCS", %{order: order, original_url: original_url} do
      test_pid = self()

      Picsello.PhotoStorageMock
      |> Mox.expect(:initiate_resumable, fn path, "application/zip" ->
        assert ["galleries", gallery_id, "orders", filename] = Path.split(path)
        assert gallery_id == to_string(order.gallery_id)

        assert "#{order.gallery.name} - #{Picsello.Orders.number(order)}.zip" == filename

        {:ok, %{headers: [{"location", "http://example.com"}], status: 200}}
      end)
      |> Mox.expect(:continue_resumable, fn "http://example.com", chunk, opts ->
        assert is_binary(chunk)

        assert byte_size(chunk) == header(opts, "content-length")

        assert "bytes 0-#{byte_size(chunk) - 1}/#{byte_size(chunk)}" ==
                 header(opts, "content-range")

        send(test_pid, {:chunk, chunk})

        {:ok, %{status: 200}}
      end)

      add_digital(order, original_url)

      assert {:ok, _} = Picsello.Orders.Pack.upload(order.id)

      assert_receive {:chunk, chunk}

      assert ["my photo.png"] = get_zip_files(chunk)
    end

    test "chunks the upload to GCS", %{order: order, original_url: original_url} do
      test_pid = self()
      add_digital(order, original_url)

      Picsello.PhotoStorageMock
      |> Mox.stub(:initiate_resumable, fn _, _ ->
        {:ok, %{headers: [{"location", ""}], status: 200}}
      end)
      |> Mox.stub(:continue_resumable, fn _, chunk, opts ->
        range =
          Regex.named_captures(
            ~r/^bytes (?<first>\d+)\-(?<last>\d+)\/(?<total>.+)$/,
            header(opts, "content-range")
          )

        message =
          case range do
            %{"total" => "*", "first" => first} -> {:chunk, chunk, String.to_integer(first)}
            _ -> {:last_chunk, chunk}
          end

        send(test_pid, message)

        {:ok, %{status: 200}}
      end)

      assert {:ok, _} = Picsello.Orders.Pack.upload(order.id, chunk_size: 128)

      assert_receive {:last_chunk, last_chunk}, 1000
      {:messages, messages} = :erlang.process_info(test_pid, :messages)

      zip =
        for {:chunk, chunk, start} <- messages do
          {start, chunk}
        end
        |> Enum.sort_by(&elem(&1, 0))
        |> Enum.map(&elem(&1, 1))
        |> Enum.reduce(&(&2 <> &1))

      assert ["my photo.png"] = get_zip_files(zip <> last_chunk)
    end
  end

  describe "chunk_every" do
    def chunk_every(iodata, size) do
      iodata
      |> Picsello.Orders.Pack.IodataStream.chunk_every(size)
      |> Enum.map(&IO.iodata_to_binary/1)
    end

    test "breaks apart stream iodata binaries" do
      assert ["br", "ia", "np", "at", "ri", "ck", "du", "n"] ==
               [["brian"], 'patr', 'ick', ["du"], 'n'] |> chunk_every(2)
    end

    test "chunks when stream iodata elements are larger or smaller than size" do
      assert ["br", "ia", "np", "at", "ri", "ck", "du", "n"] ==
               ['brian', 'patr', 'ick', 'du', 'n'] |> chunk_every(2)
    end
  end
end
