defmodule Picsello.NylasDetails do
  @moduledoc false
  alias Picsello.{Repo, Workers.CalendarEvent, NylasDetail}
  alias Ecto.{Changeset, Multi}

  @spec set_nylas_token!(NylasDetail.t(), map()) :: NylasDetail.t()
  def set_nylas_token!(%NylasDetail{} = nylas_detail, attrs) do
    nylas_detail
    |> NylasDetail.set_token_changeset(attrs)
    |> Repo.update!()
  end

  @spec clear_nylas_token!(NylasDetail.t()) :: NylasDetail.t()
  def clear_nylas_token!(%NylasDetail{} = nylas_detail) do
    nylas_detail
    |> NylasDetail.clear_token_changeset()
    |> Repo.update!()
  end

  @spec set_nylas_calendars!(NylasDetail.t(), map()) :: NylasDetail.t()
  def set_nylas_calendars!(%NylasDetail{user_id: user_id} = nylas_detail, calendars) do
    changeset = NylasDetail.set_calendars_changeset(nylas_detail, calendars)

    case nylas_detail do
      %{event_status: :in_progress} ->
        Multi.new()
        |> Multi.update(:nylas_detail, changeset)
        |> Oban.insert(
          :move_events,
          CalendarEvent.new(%{type: "move", user_id: user_id})
        )
        |> Repo.transaction()
        |> then(fn {:ok, %{nylas_detail: nylas_detail}} -> nylas_detail end)

      _ ->
        changeset
        |> NylasDetail.event_status_change()
        |> Repo.update!()
    end
  end

  @spec reset_event_status!(NylasDetail.t()) :: NylasDetail.t()
  def reset_event_status!(%NylasDetail{} = nylas_detail) do
    nylas_detail
    |> Changeset.change()
    |> NylasDetail.event_status_change()
    |> Repo.update!()
  end
end
