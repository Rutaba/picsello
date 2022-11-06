defmodule PicselloWeb.JobDownloadController do
  use PicselloWeb, :controller

  alias Picsello.BookingProposal

  def download_invoice_pdf(conn, %{"booking_proposal_id" => booking_proposal_id}) do
    %{
      job:
        %{
          client: client,
          shoots: shoots,
          package: %{organization: %{user: photographer} = organization} = package
        } = job
    } =
      proposal =
      booking_proposal_id
      |> BookingProposal.by_id()
      |> BookingProposal.preloads()

    PicselloWeb.PDFView.render("job_invoice.html", %{
      read_only: true,
      job: job,
      proposal: proposal,
      photographer: photographer,
      organization: organization,
      client: client,
      shoots: shoots,
      package: package
    })
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
    |> PdfGenerator.generate(page_size: "A5")
    |> then(fn {:ok, path} ->
      conn
      |> put_resp_content_type("pdf")
      |> put_resp_header(
        "content-disposition",
        PicselloWeb.GalleryDownloadsController.encode_header_value("job_invoice.pdf")
      )
      |> send_resp(200, File.read!(path))
    end)
  end
end
