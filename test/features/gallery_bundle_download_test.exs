defmodule Picsello.GalleryBundleDownloadTest do
  use Picsello.FeatureCase, async: true
  import Mox
  import Money.Sigils
  use Oban.Testing, repo: Picsello.Repo

  setup :verify_on_exit!

  def gcs_resp(status),
    do:
      &(&1
        |> Plug.Conn.put_resp_header("Access-Control-Allow-Origin", "*")
        |> Plug.Conn.resp(status, ""))

  setup do
    %{port: port} = bypass = Bypass.open()
    bypass_url = PicselloWeb.Endpoint.struct_url() |> Map.put(:port, port) |> URI.to_string()

    bypass
    |> Bypass.stub("OPTIONS", "/", gcs_resp(200))

    bypass
    |> Bypass.stub("POST", "/", gcs_resp(204))

    Picsello.PhotoStorageMock
    |> stub(:get, fn _ -> {:ok, %{name: "gallery.zip"}} end)
    |> stub(:path_to_url, fn _path -> image_url() end)
    |> stub(:params_for_upload, fn _ -> %{url: bypass_url, fields: %{key: "image.png"}} end)
    |> stub(:delete, fn _ -> :ok end)
    |> stub(:initiate_resumable, fn _, _ ->
      {:ok, %Tesla.Env{status: 200} |> Tesla.put_header("location", "https://example.com")}
    end)
    |> stub(:continue_resumable, fn _, _, _ ->
      {:ok, %Tesla.Env{status: 200}}
    end)

    :ok
  end

  setup :onboarded
  setup :authenticated
  setup :authenticated_gallery

  setup do
    organization = insert(:organization, stripe_account_id: "photographer-stripe-account-id")

    insert(:user,
      organization: organization,
      stripe_customer_id: "photographer-stripe-customer-id"
    )
    |> onboard!()

    package =
      insert(:package,
        organization: organization,
        download_each_price: ~M[2500]USD,
        buy_all: ~M[5000]USD
      )

    gallery =
      insert(:gallery,
        job:
          insert(:lead,
            client: insert(:client, organization: organization),
            package: package
          ),
        use_global: %{watermark: true, expiration: true, digital: true, products: true}
      )

      insert(:order, gallery: gallery, bundle_price: ~M[5000]USD, placed_at: DateTime.utc_now())
      insert(:gallery_digital_pricing, %{gallery: gallery, download_count: 0, print_credits: Money.new(0)})
      Mox.stub(Picsello.MockPayments, :retrieve_customer, fn "photographer-stripe-customer-id", _ ->
        {:ok, %Stripe.Customer{invoice_settings: %{default_payment_method: "pm_12345"}}}
      end)

    [gallery: gallery]
  end

  setup :authenticated_gallery_client
  test "resets client link when photographer updates gallery", %{
    session: session,
    gallery: gallery
  } do
    session
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> assert_text(gallery.name)
    |> click(link("View Gallery"))
    |> assert_has(link("Download all"))

    session
    |> visit(Routes.gallery_photos_index_path(PicselloWeb.Endpoint, :index, gallery.id))
    |> assert_text(gallery.name)
    |> attach_file(file_field("Add photos", visible: false),
      path: "assets/static/images/phoenix.png"
    )
    |> assert_has(css(".muuri-item"))

    assert_enqueued([worker: Picsello.Workers.PackGallery], 1000)

    assert [
             %{worker: "Picsello.Workers.PackDigitals", state: "scheduled"},
             %{worker: "Picsello.Workers.PackGallery", state: "completed"}
           ] = run_jobs()


    assert [
             %{worker: "Picsello.Workers.PackGallery", state: "completed"},
             %{worker: "Picsello.Workers.PackDigitals", state: "completed"}
           ] = run_jobs(with_scheduled: true)

    assert_receive({:delivered_email, %{subject: "Download Ready"}})

    session
    |> visit("/gallery/#{gallery.client_link_hash}")
    |> assert_has(link("Download all"))

    session
    |> visit("/galleries/#{gallery.id}/photos")
    |> click(css("div[id$='-remove']", visible: false))
    |> click(button("Yes, delete"))
    |> assert_text("nothing here")

    assert [
             %{worker: "Picsello.Workers.PackDigitals", state: "scheduled"},
             %{worker: "Picsello.Workers.PackGallery", state: "completed"}
           ] = run_jobs() |> Enum.drop(2)


    assert [
             %{worker: "Picsello.Workers.PackGallery", state: "completed"},
             %{worker: "Picsello.Workers.PackDigitals", state: "completed"}
           ] = run_jobs(with_scheduled: true) |> Enum.drop(2)
  end
end
