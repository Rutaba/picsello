defmodule Picsello.BookingEvents do
  @moduledoc "context module for booking events"
  alias Picsello.Repo

  def upsert_booking_event(changeset) do
    changeset
    |> Repo.insert(
      on_conflict: :replace_all,
      conflict_target: [:id],
      returning: true
    )
  end
end
