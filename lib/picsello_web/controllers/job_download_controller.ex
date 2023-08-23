defmodule PicselloWeb.JobDownloadController do
  use PicselloWeb, :controller

  import PicselloWeb.BookingProposalLive.Shared, only: [get_print_credit: 1, get_amount: 1]
  import Picsello.Profiles, only: [logo_url: 1]
  alias Picsello.{Repo, BookingProposal, Contracts}

  def download_invoice_pdf(conn, %{"booking_proposal_id" => booking_proposal_id}) do
    %{
      job:
        %{
          client: client,
          shoots: shoots,
          package:
            %{contract: contract, organization: %{user: photographer} = organization} = package
        } = job
    } =
      proposal =
      booking_proposal_id
      |> BookingProposal.by_id()
      |> BookingProposal.preloads()
      |> Repo.preload([:questionnaire, :answer, job: [package: [:contract]]])

    print_credit = get_print_credit(package)
    amount = get_amount(print_credit)
    organization_logo_url = logo_url(organization)

    PicselloWeb.PDFView.render("job_invoice.html", %{
      read_only: true,
      job: job,
      proposal: proposal,
      photographer: photographer,
      organization: organization,
      client: client,
      shoots: shoots,
      package: package,
      contract: contract,
      organization_logo_url: organization_logo_url,
      contract_content:
        Contracts.contract_content(
          contract,
          package,
          PicselloWeb.Helpers
        ),
      print_credit: print_credit,
      amount: amount
    })
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
    |> PdfGenerator.generate(
      page_size: "A5",
      shell_params: [
        "--footer-right",
        "[page] / [toPage]",
        "--footer-font-size",
        "5",
        "--footer-font-name",
        "Montserrat"
      ]
    )
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
