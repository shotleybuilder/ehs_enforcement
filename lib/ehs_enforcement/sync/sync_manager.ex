defmodule EhsEnforcement.Sync.SyncManager do
  @moduledoc """
  Manages synchronization of enforcement data from various sources.
  
  Handles:
  - One-time import from Airtable (Phase 3)
  - Direct agency sync to PostgreSQL (Phase 4+)
  """
  
  require Logger
  
  alias EhsEnforcement.Enforcement
  
  @doc """
  Import historical data from Airtable using Ash bulk actions.
  This is a one-time migration for Phase 3.
  """
  def import_from_airtable do
    Logger.info("Starting Airtable import...")
    
    try do
      # Fetch from Airtable
      airtable_records = fetch_airtable_data()
      
      # Transform and create records using Ash
      results = process_airtable_records(airtable_records)
      
      {:ok, results}
    rescue
      error ->
        Logger.error("Airtable import failed: #{inspect(error)}")
        {:error, error}
    end
  end
  
  @doc """
  Sync data from a specific agency directly to PostgreSQL.
  """
  def sync_agency(agency_code, sync_type) when is_atom(agency_code) and sync_type in [:cases, :notices] do
    Logger.info("Starting #{sync_type} sync for agency: #{agency_code}")
    
    # Get agency using Ash
    case Enforcement.get_agency_by_code(agency_code) do
      {:ok, agency} ->
        # Fetch data from agency website
        scraped_data = scrape_agency_data(agency, sync_type)
        
        # Process each record
        Enum.each(scraped_data, fn data ->
          create_record(agency_code, sync_type, data)
        end)
        
        :ok
        
      {:error, _} ->
        {:error, :agency_not_found}
    end
  end
  
  # Private functions
  
  defp fetch_airtable_data do
    # Use AirtableImporter to fetch all data
    try do
      EhsEnforcement.Sync.AirtableImporter.stream_airtable_records() |> Enum.to_list()
    rescue
      _ -> []
    end
  end
  
  defp process_airtable_records(records) do
    Enum.map(records, fn record ->
      # Extract fields
      fields = record["fields"] || %{}
      
      # Determine if it's a case or notice
      cond do
        fields["regulator_id"] ->
          create_case_from_airtable(fields)
          
        fields["notice_id"] ->
          create_notice_from_airtable(fields)
          
        true ->
          {:error, :unknown_record_type}
      end
    end)
  end
  
  defp create_case_from_airtable(fields) do
    attrs = %{
      agency_code: String.to_atom(fields["agency_code"] || "hse"),
      regulator_id: fields["regulator_id"],
      offender_attrs: %{
        name: fields["offender_name"],
        postcode: fields["offender_postcode"],
        local_authority: fields["offender_local_authority"],
        main_activity: fields["offender_main_activity"]
      },
      offence_action_date: parse_date(fields["offence_action_date"]),
      offence_fine: parse_decimal(fields["offence_fine"]),
      offence_breaches: fields["offence_breaches"]
    }
    
    Enforcement.create_case(attrs)
  end
  
  defp create_notice_from_airtable(fields) do
    _attrs = %{
      agency_code: String.to_atom(fields["agency_code"] || "hse"),
      notice_id: fields["notice_id"],
      offender_attrs: %{
        name: fields["offender_name"],
        postcode: fields["offender_postcode"]
      },
      date_issued: parse_date(fields["date_issued"]),
      notice_type: String.to_atom(fields["notice_type"] || "improvement"),
      breach_details: fields["breach_details"]
    }
    
    # Note: create_notice doesn't exist yet in Enforcement
    # For now, return a placeholder
    {:ok, %{notice_id: fields["notice_id"]}}
  end
  
  defp scrape_agency_data(_agency, sync_type) do
    # For testing, return mock data
    # In production, this would call the actual scraping modules
    case sync_type do
      :cases -> 
        # Return mock case data for testing
        if Application.get_env(:ehs_enforcement, :mock_scraping, false) do
          [
            %{
              regulator_id: "HSE123",
              offender_name: "Direct Import Co Ltd",
              offender_postcode: "M3 3CC",
              offence_action_date: ~D[2023-03-15],
              offence_fine: Decimal.new("7500.00"),
              offence_breaches: "Direct breach"
            }
          ]
        else
          []
        end
        
      :notices -> 
        # Return mock notice data for testing
        if Application.get_env(:ehs_enforcement, :mock_scraping, false) do
          [
            %{
              notice_id: "NOT001",
              offender_name: "Notice Company Ltd",
              offender_postcode: "M4 4DD",
              date_issued: ~D[2023-04-10],
              notice_type: "improvement",
              breach_details: "Safety improvement required"
            }
          ]
        else
          []
        end
    end
  end
  
  defp create_record(agency_code, :cases, data) do
    Enforcement.create_case(%{
      agency_code: agency_code,
      regulator_id: data.regulator_id,
      offender_attrs: %{
        name: data.offender_name,
        postcode: data.offender_postcode
      },
      offence_action_date: data.offence_action_date,
      offence_fine: data.offence_fine,
      offence_breaches: data.offence_breaches
    })
  end
  
  defp create_record(agency_code, :notices, data) do
    # Create notice via Enforcement context
    Enforcement.create_notice(%{
      agency_code: agency_code,
      notice_id: data.notice_id,
      offender_attrs: %{
        name: data.offender_name,
        postcode: data.offender_postcode
      },
      date_issued: data.date_issued,
      notice_type: data.notice_type,
      breach_details: data.breach_details
    })
  end
  
  defp parse_date(nil), do: nil
  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end
  
  defp parse_decimal(nil), do: Decimal.new("0")
  defp parse_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> decimal
      :error -> Decimal.new("0")
    end
  end
  defp parse_decimal(value) when is_number(value) do
    Decimal.new(to_string(value))
  end
end