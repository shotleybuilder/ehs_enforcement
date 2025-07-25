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
      {:ok, nil} -> {:error, %Ash.Error.Query.NotFound{}}
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

  def list_cases(opts \\ []) do
    query = EhsEnforcement.Enforcement.Case
    
    # Apply filters if provided
    query = case opts[:filter] do
      nil -> query
      filters ->
        Enum.reduce(filters, query, fn
          {:regulator_id, value}, q -> Ash.Query.filter(q, regulator_id == ^value)
          {:agency_id, value}, q -> Ash.Query.filter(q, agency_id == ^value)
          _, q -> q
        end)
    end
    
    # Apply load if provided
    query = case opts[:load] do
      nil -> query
      loads -> Ash.Query.load(query, loads)
    end
    
    # Apply sort if provided
    query = case opts[:sort] do
      nil -> query
      sorts -> Ash.Query.sort(query, sorts)
    end
    
    Ash.read(query)
  end

  def list_cases!(opts \\ []) do
    case list_cases(opts) do
      {:ok, cases} -> cases
      {:error, error} -> raise error
    end
  end

  def count_cases!(opts \\ []) do
    query = EhsEnforcement.Enforcement.Case
    
    # Apply filters if provided
    query = case opts[:filter] do
      nil -> query
      filters ->
        Enum.reduce(filters, query, fn
          {:agency_id, value}, q -> Ash.Query.filter(q, agency_id == ^value)
          _, q -> q
        end)
    end
    
    case Ash.count(query) do
      {:ok, count} -> count
      {:error, error} -> raise error
    end
  end

  def aggregate_cases!(aggregate_type, field, opts \\ []) do
    query = EhsEnforcement.Enforcement.Case
    
    # Apply filters if provided
    query = case opts[:filter] do
      nil -> query
      filters ->
        Enum.reduce(filters, query, fn
          filter, q -> Ash.Query.filter(q, ^filter)
        end)
    end
    
    case Ash.aggregate(query, {aggregate_type, field}) do
      {:ok, result} -> 
        Map.get(result, aggregate_type, 0)
      {:error, error} -> 
        raise error
    end
  end

  def sum_fines!(opts \\ []) do
    aggregate_cases!(:sum, :offence_fine, opts)
  end

  # Offender list function
  def list_offenders(opts \\ []) do
    query = EhsEnforcement.Enforcement.Offender
    
    # Apply filters if provided
    query = case opts[:filter] do
      nil -> query
      filters -> Ash.Query.filter(query, ^filters)
    end
    
    # Apply sort if provided
    query = case opts[:sort] do
      nil -> query
      sorts -> Ash.Query.sort(query, sorts)
    end
    
    # Apply limit if provided
    query = case opts[:limit] do
      nil -> query
      limit -> Ash.Query.limit(query, limit)
    end
    
    # Apply load if provided
    query = case opts[:load] do
      nil -> query
      loads -> Ash.Query.load(query, loads)
    end
    
    Ash.read(query)
  end

  def list_offenders!(opts \\ []) do
    case list_offenders(opts) do
      {:ok, offenders} -> offenders
      {:error, error} -> raise error
    end
  end

  # Notice functions
  def create_notice(attrs) do
    # Since Notice resource doesn't exist yet, return a placeholder
    # This will be implemented when Notice resource is added
    {:ok, %{
      notice_id: attrs[:notice_id],
      agency_code: attrs[:agency_code],
      offender_name: get_in(attrs, [:offender_attrs, :name]),
      notice_type: attrs[:notice_type]
    }}
  end

  def list_notices(_opts \\ []) do
    # Since Notice resource doesn't exist yet, return empty list
    # This will be implemented when Notice resource is added
    {:ok, []}
  end

  def list_notices!(opts \\ []) do
    case list_notices(opts) do
      {:ok, notices} -> notices
      {:error, error} -> raise error
    end
  end
end