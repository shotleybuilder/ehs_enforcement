defmodule EhsEnforcement.Enforcement do
  @moduledoc """
  The Enforcement domain for managing enforcement agencies, cases, notices, and related entities.
  """
  
  use Ash.Domain
  
  require Ash.Query

  resources do
    resource EhsEnforcement.Enforcement.Agency
    resource EhsEnforcement.Enforcement.Offender
    resource EhsEnforcement.Enforcement.Case
    resource EhsEnforcement.Enforcement.Notice
    resource EhsEnforcement.Enforcement.Breach
  end

  # Convenience functions for common operations

  # Agency functions
  def create_agency(attrs) do
    EhsEnforcement.Enforcement.Agency
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end

  def list_agencies!() do
    EhsEnforcement.Enforcement.Agency
    |> Ash.read!()
  end

  def get_agency!(id) do
    agency = EhsEnforcement.Enforcement.Agency
    |> Ash.get!(id)
    {:ok, agency}
  end

  def update_agency(agency, attrs) do
    agency
    |> Ash.Changeset.for_update(:update, attrs)
    |> Ash.update()
  end

  def get_agency_by_code(code) do
    EhsEnforcement.Enforcement.Agency
    |> Ash.Query.filter(code == ^code)
    |> Ash.read_one()
  end

  # Offender functions
  def create_offender(attrs) do
    EhsEnforcement.Enforcement.Offender
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end

  def get_offender!(id, opts \\ []) do
    offender = EhsEnforcement.Enforcement.Offender
    |> Ash.get!(id, opts)
    {:ok, offender}
  end

  def update_offender_statistics(offender, attrs) do
    offender
    |> Ash.Changeset.for_update(:update_statistics, attrs)
    |> Ash.update()
  end

  def search_offenders(query) do
    EhsEnforcement.Enforcement.Offender
    |> Ash.Query.for_read(:search, %{query: query})
    |> Ash.read()
  end

  def get_offender_by_name_and_postcode(name, postcode) do
    query = if postcode do
      EhsEnforcement.Enforcement.Offender
      |> Ash.Query.filter(name == ^name and postcode == ^postcode)
    else
      EhsEnforcement.Enforcement.Offender
      |> Ash.Query.filter(name == ^name and is_nil(postcode))
    end
    
    case query |> Ash.read_one() do
      {:ok, nil} -> {:error, :not_found}
      result -> result
    end
  end

  # Case functions
  def create_case(attrs) do
    EhsEnforcement.Enforcement.Case
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create()
  end

  def get_case!(id, opts \\ []) do
    case_record = EhsEnforcement.Enforcement.Case
    |> Ash.get!(id, opts)
    {:ok, case_record}
  end

  def sync_case(case_record, attrs) do
    case_record
    |> Ash.Changeset.for_update(:sync, attrs)
    |> Ash.update()
  end

  def list_cases_by_date_range(from_date, to_date) do
    EhsEnforcement.Enforcement.Case
    |> Ash.Query.for_read(:by_date_range, %{from_date: from_date, to_date: to_date})
    |> Ash.read()
  end
end