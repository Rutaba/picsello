defmodule Picsello.PackTest do
  use Picsello.DataCase, async: true
  import Money.Sigils
  alias Picsello.Pack

  @original_url image_url()

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

  def insert_gallery(opts \\ []) do
    {charge_for_downloads, opts} = Keyword.pop(opts, :charge_for_downloads, true)
    download_each_price = if charge_for_downloads, do: ~M[1]USD, else: ~M[0]USD

    org_attrs =
      case Keyword.get(opts, :organization_name) do
        nil -> %{}
        name -> %{name: name}
      end

    organization = insert(:organization, org_attrs)

    insert(:gallery,
      job:
        insert(:lead,
          client: insert(:client, organization: organization),
          package:
            insert(:package, organization: organization, download_each_price: download_each_price)
        )
    )
  end

  setup do
    Mox.verify_on_exit!()

    Picsello.PhotoStorageMock
    |> Mox.stub(:path_to_url, fn _ -> @original_url end)
    |> Mox.stub(:initiate_resumable, fn _, _ ->
      {:ok, %Tesla.Env{headers: [{"location", "http://example.com"}], status: 200}}
    end)
    |> Mox.stub(:continue_resumable, fn "http://example.com", _chunk, _opts ->
      {:ok, %Tesla.Env{status: 200}}
    end)

    :ok
  end

  describe "upload - gallery" do
    test "zips all photos when bundle is purchased", %{} do
      gallery = insert_gallery(organization_name: "org name")

      insert_list(3, :photo,
        gallery: gallery,
        original_url: @original_url,
        name: "original name.jpg"
      )

      assert {:error, _} = Pack.upload(gallery)

      insert(:order, gallery: gallery, placed_at: DateTime.utc_now(), bundle_price: ~M[5000]USD)

      assert {:ok, _} = Pack.upload(gallery)
    end

    test "sends a zip of all photos when package does not charge for downloads", %{} do
      gallery = insert_gallery(organization_name: "org name", charge_for_downloads: false)

      insert_list(3, :photo,
        gallery: gallery,
        original_url: @original_url,
        name: "original name.jpg"
      )

      assert {:ok, _} = Pack.upload(gallery)
    end
  end

  describe "upload - order" do
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

      assert {:error, "no client paid order" <> _} = Picsello.Pack.upload(order)
    end

    test "no digitals in order - is an error", %{order: order} do
      assert {:error, :empty} = Picsello.Pack.upload(order)
    end

    test "streams the upload to GCS", %{order: order} do
      test_pid = self()

      Picsello.PhotoStorageMock
      |> Mox.expect(:initiate_resumable, fn path, "application/zip" ->
        assert ["galleries", gallery_id, "orders", filename] = Path.split(path)
        assert gallery_id == to_string(order.gallery_id)

        assert "#{order.gallery.name} - #{Picsello.Orders.number(order)}.zip" == filename

        {:ok, %Tesla.Env{headers: [{"location", "http://example.com"}], status: 200}}
      end)
      |> Mox.expect(:continue_resumable, fn "http://example.com", chunk, opts ->
        assert is_binary(chunk)

        assert byte_size(chunk) == header(opts, "content-length")

        assert "bytes 0-#{byte_size(chunk) - 1}/#{byte_size(chunk)}" ==
                 header(opts, "content-range")

        send(test_pid, {:chunk, chunk})

        {:ok, %{status: 200}}
      end)

      add_digital(order, @original_url)

      assert {:ok, _} = Picsello.Pack.upload(order)

      assert_receive {:chunk, chunk}

      assert ["my photo.png"] = get_zip_files(chunk)
    end

    test "chunks the upload to GCS", %{order: order} do
      test_pid = self()
      add_digital(order, @original_url)

      Picsello.PhotoStorageMock
      |> Mox.stub(:initiate_resumable, fn _, _ ->
        {:ok, %Tesla.Env{headers: [{"location", ""}], status: 200}}
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

        {:ok, %Tesla.Env{status: 200}}
      end)

      assert {:ok, _} = Picsello.Pack.upload(order, chunk_size: 128)

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

  describe "IodataStream.chunk_every" do
    def chunk_every(iodata, size) do
      iodata
      |> Picsello.Pack.IodataStream.chunk_every(size)
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

  describe "IodataStream.split" do
    def split(iodata, size), do: Picsello.Pack.IodataStream.split(iodata, size)

    test "may not create new binaries" do
      assert {'br', [["ian"], ?d]} ==
               [?b, ?r, ["ian"], ?d] |> split(2)
    end

    test "can split 1 binary" do
      assert {["br"], ["ian"]} ==
               ["brian"] |> split(2)
    end

    test "returns iodata if smaller than size" do
      assert {['bri', 'a'], []} ==
               ['bri', 'a'] |> split(5)
    end

    test "only creates binary when split point is spanned" do
      assert {[?b, "r"], ["ian", ?d]} ==
               [?b, ["rian"], ?d] |> split(2)
    end
  end
end
