defmodule Picsello.PreferredFilterTest do
  @moduledoc false
  use Picsello.DataCase, async: true

  alias Picsello.{
    PreferredFilter,
    PreferredFilter.Filters
  }
  import PicselloWeb.Live.Shared, only: [save_filters: 3]
  alias Ecto.Changeset

  setup do
   org = insert(:organization)
   filters = %{sort_by: "name", job_type: "wedding", job_status: "active", sort_direction: "asc"}

   %{organization: org, filters: filters}
  end

  test "changeset for embeded schema of filter", %{filters: filters} do
    changeset = Filters.changeset(%Filters{}, filters)

    assert changeset.valid?
    assert get_change(changeset, :job_status) == "active"
    assert get_change(changeset, :job_type) == "wedding"
  end

  test "changeset for PreferredFilter for job and clients", %{organization: org, filters: filters} do
    preferred_filter_params = %{type: "jobs", filters: filters, organization_id: org.id}

    changeset = PreferredFilter.changeset(%PreferredFilter{}, preferred_filter_params)

    assert changeset.valid?
    assert get_change(changeset, :organization_id) == org.id
    assert get_change(changeset, :type) == "jobs"
  end


  test "insert in prefered filters", %{organization: org, filters: filters} do
    {:ok, preferd_filter} = save_filters(org.id, "clients", filters)

    assert preferd_filter.organization_id == org.id
  end


  test "update prefered filters record", %{organization: org} do
    insert(:prefer_filter, organization: org, type: "clients")

    filters = %{sort_direction: "desc"}
    {:ok, preferd_filter} = save_filters(org.id, "clients", filters)

    assert preferd_filter.filters.sort_direction == "desc"
  end

  test "get filter", %{organization: org} do
    insert(:prefer_filter, organization: org, type: "booking_events")
    filter =  PreferredFilter.load_preferred_filters(org.id, "booking_events")

    assert filter.organization_id == org.id
  end
end
