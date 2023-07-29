defmodule PicselloWeb.BookingProposalLive.ProposalComponentTest do
  use PicselloWeb.ConnCase
  import Phoenix.LiveViewTest

  def render_package(attrs) do
    user = insert(:user)
    package = insert(:package, [user: user] ++ attrs)
    job = insert(:lead, package: package, user: user)
    proposal = insert(:proposal, job: job)

    render_component(PicselloWeb.BookingProposalLive.ProposalComponent,
      id: :test,
      job: job,
      package: package,
      photographer: user,
      proposal: proposal,
      organization: user.organization,
      shoots: job.shoots,
      client: job.client,
      read_only: true
    )
  end

  test "downloads included" do
    assert String.contains?(
             render_package(
               download_count: 0,
               download_each_price: %Money{amount: 0, currency: :USD}
             ),
             "All photos downloadable"
           )
  end

  test "charge for downloads" do
    assert String.contains?(
             render_package(
               download_count: 0,
               download_each_price: %Money{amount: 50, currency: :USD}
             ),
             "Download photos @ 0.50 USD/ea"
           )
  end

  test "include credits" do
    html =
      render_package(download_count: 1, download_each_price: %Money{amount: 50, currency: :USD})

    assert String.contains?(html, "1 photo download")
    assert String.contains?(html, "Additional downloads @ 0.50 USD/ea")
  end
end
