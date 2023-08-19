defmodule PicselloWeb.PDFView do
  use PicselloWeb, :view
  alias Picsello.{PaymentSchedules}

  import PicselloWeb.BookingProposalLive.ScheduleComponent,
    only: [make_status: 1, status_class: 1]
end
