defmodule EhsEnforcement.Sync do
  @moduledoc """
  The Sync domain for managing synchronization operations and logs.
  Provides administrative functions for importing and syncing data from external sources.
  """
  
  use Ash.Domain
  
  alias EhsEnforcement.Sync.AirtableImporter
  alias EhsEnforcement.Integrations.Airtable.ReqClient
  require Logger

  resources do
    resource EhsEnforcement.Sync.SyncLog
  end

  @doc """
  Import notice records from Airtable.
  
  This function streams records from Airtable, filters for notice types
  (records where offence_action_type contains "Notice"), and imports them
  into the notices table with proper relationships.
  
  ## Options
  
  * `:limit` - Maximum number of records to import (default: 1000)
  * `:batch_size` - Number of records to process per batch (default: 100)
  * `:actor` - The user performing the import (for authorization)
  
  ## Examples
  
      # Import 1000 notice records
      EhsEnforcement.Sync.import_notices()
      
      # Import 500 notice records
      EhsEnforcement.Sync.import_notices(limit: 500)
      
      # Import with specific actor for authorization
      EhsEnforcement.Sync.import_notices(actor: admin_user)
  
  ## Returns
  
  * `{:ok, %{imported: count, errors: errors}}` - Success with statistics
  * `{:error, reason}` - Failure with error details
  """
  def import_notices(opts \\ []) do
    limit = Keyword.get(opts, :limit, 1000)
    batch_size = Keyword.get(opts, :batch_size, 100)
    actor = Keyword.get(opts, :actor)
    
    Logger.info("🔍 Starting import of up to #{limit} notice records from Airtable...")
    
    with :ok <- validate_import_preconditions(),
         {:ok, stats} <- do_import_notices(limit, batch_size, actor) do
      Logger.info("✅ Notice import completed successfully")
      {:ok, stats}
    else
      {:error, reason} ->
        Logger.error("❌ Notice import failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Import case records from Airtable.
  
  This function streams records from Airtable, filters for case types
  (records where offence_action_type is "Court Case" or "Caution"), and imports them
  into the cases table with proper relationships.
  
  ## Options
  
  * `:limit` - Maximum number of records to import (default: 1000)
  * `:batch_size` - Number of records to process per batch (default: 100)
  * `:actor` - The user performing the import (for authorization)
  
  ## Examples
  
      # Import 1000 case records
      EhsEnforcement.Sync.import_cases()
      
      # Import 500 case records
      EhsEnforcement.Sync.import_cases(limit: 500)
      
      # Import with specific actor for authorization
      EhsEnforcement.Sync.import_cases(actor: admin_user)
  
  ## Returns
  
  * `{:ok, %{imported: count, errors: errors}}` - Success with statistics
  * `{:error, reason}` - Failure with error details
  """
  def import_cases(opts \\ []) do
    limit = Keyword.get(opts, :limit, 1000)
    batch_size = Keyword.get(opts, :batch_size, 100)
    actor = Keyword.get(opts, :actor)
    
    Logger.info("🔍 Starting import of up to #{limit} case records from Airtable...")
    
    with :ok <- validate_import_preconditions(),
         {:ok, stats} <- do_import_cases(limit, batch_size, actor) do
      Logger.info("✅ Case import completed successfully")
      {:ok, stats}
    else
      {:error, reason} ->
        Logger.error("❌ Case import failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get import statistics for notices.
  
  Returns counts of total notices, recent imports, and error rates.
  """
  def get_notice_import_stats do
    with {:ok, total_notices} <- count_notices(),
         {:ok, recent_imports} <- count_recent_notice_imports(),
         {:ok, error_rate} <- calculate_import_error_rate() do
      {:ok, %{
        total_notices: total_notices,
        recent_imports: recent_imports,
        error_rate: error_rate
      }}
    end
  end

  @doc """
  Get import statistics for cases.
  
  Returns counts of total cases, recent imports, and error rates.
  """
  def get_case_import_stats do
    with {:ok, total_cases} <- count_cases(),
         {:ok, recent_imports} <- count_recent_case_imports(),
         {:ok, error_rate} <- calculate_import_error_rate() do
      {:ok, %{
        total_cases: total_cases,
        recent_imports: recent_imports,
        error_rate: error_rate
      }}
    end
  end

  @doc """
  Clean up orphaned offenders that have no associated cases or notices.
  
  This function identifies and removes offender records that are no longer
  referenced by any cases or notices. This can happen when cases/notices
  are deleted but the database foreign keys don't cascade delete.
  
  ## Options
  
  * `:dry_run` - If true, only count orphaned offenders without deleting (default: false)
  * `:actor` - The user performing the cleanup (for authorization)
  
  ## Examples
  
      # Count orphaned offenders without deleting
      EhsEnforcement.Sync.cleanup_orphaned_offenders(dry_run: true)
      
      # Actually delete orphaned offenders
      EhsEnforcement.Sync.cleanup_orphaned_offenders()
  
  ## Returns
  
  * `{:ok, %{orphaned_count: count, deleted_count: deleted}}` - Success with counts
  * `{:error, reason}` - Failure with error details
  """
  def cleanup_orphaned_offenders(opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    actor = Keyword.get(opts, :actor)
    
    Logger.info("🧹 Starting orphaned offender cleanup (dry_run: #{dry_run})...")
    
    with {:ok, orphaned_count} <- count_orphaned_offenders(),
         {:ok, deleted_count} <- do_cleanup_orphaned_offenders(dry_run, actor) do
      
      if dry_run do
        Logger.info("🔍 Found #{orphaned_count} orphaned offenders (dry run - no deletion)")
        {:ok, %{orphaned_count: orphaned_count, deleted_count: 0}}
      else
        Logger.info("✅ Cleanup completed. Found: #{orphaned_count}, Deleted: #{deleted_count}")
        {:ok, %{orphaned_count: orphaned_count, deleted_count: deleted_count}}
      end
    else
      {:error, reason} ->
        Logger.error("❌ Orphaned offender cleanup failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private functions

  defp validate_import_preconditions do
    # Check Airtable connection
    case test_airtable_connection() do
      :ok -> 
        Logger.info("✅ Airtable connection validated")
        :ok
      {:error, reason} -> 
        Logger.error("❌ Airtable connection failed: #{inspect(reason)}")
        {:error, {:airtable_connection_failed, reason}}
    end
  end

  defp test_airtable_connection do
    path = "/appq5OQW9bTHC1zO5/tbl6NZm9bLU2ijivf"
    
    case ReqClient.get(path, %{maxRecords: 1}) do
      {:ok, _response} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp do_import_notices(limit, batch_size, actor) do
    Logger.info("📥 Starting notice import with limit: #{limit}, batch_size: #{batch_size}")
    
    imported_count = 0
    error_count = 0
    
    result = AirtableImporter.stream_airtable_records()
    |> Stream.filter(&is_notice_record?/1)
    |> Stream.take(limit)
    |> Stream.chunk_every(batch_size)
    |> Stream.with_index()
    |> Enum.reduce_while({imported_count, error_count}, fn {batch, batch_index}, {acc_imported, acc_errors} ->
      batch_number = batch_index + 1
      Logger.info("📦 Processing batch #{batch_number} (#{length(batch)} notice records)")
      
      case import_notice_batch(batch, actor) do
        {:ok, batch_stats} ->
          new_imported = acc_imported + batch_stats.imported
          new_errors = acc_errors + batch_stats.errors
          
          Logger.info("✅ Batch #{batch_number} completed. Imported: #{batch_stats.imported}, Errors: #{batch_stats.errors}")
          
          if new_imported >= limit do
            {:halt, {new_imported, new_errors}}
          else
            {:cont, {new_imported, new_errors}}
          end
          
      end
    end)
    
    case result do
      {imported, errors} ->
        Logger.info("🎉 Import completed! Imported: #{imported}, Errors: #{errors}")
        {:ok, %{imported: imported, errors: errors}}
        
      error ->
        Logger.error("💥 Import failed: #{inspect(error)}")
        {:error, error}
    end
  end

  defp do_import_cases(limit, batch_size, actor) do
    Logger.info("📥 Starting case import with limit: #{limit}, batch_size: #{batch_size}")
    
    imported_count = 0
    error_count = 0
    
    result = AirtableImporter.stream_airtable_records()
    |> Stream.filter(&is_case_record?/1)
    |> Stream.take(limit)
    |> Stream.chunk_every(batch_size)
    |> Stream.with_index()
    |> Enum.reduce_while({imported_count, error_count}, fn {batch, batch_index}, {acc_imported, acc_errors} ->
      batch_number = batch_index + 1
      Logger.info("📦 Processing batch #{batch_number} (#{length(batch)} case records)")
      
      case import_case_batch(batch, actor) do
        {:ok, batch_stats} ->
          new_imported = acc_imported + batch_stats.imported
          new_errors = acc_errors + batch_stats.errors
          
          Logger.info("✅ Batch #{batch_number} completed. Imported: #{batch_stats.imported}, Errors: #{batch_stats.errors}")
          
          if new_imported >= limit do
            {:halt, {new_imported, new_errors}}
          else
            {:cont, {new_imported, new_errors}}
          end
          
      end
    end)
    
    case result do
      {imported, errors} ->
        Logger.info("🎉 Case import completed! Imported: #{imported}, Errors: #{errors}")
        {:ok, %{imported: imported, errors: errors}}
        
      error ->
        Logger.error("💥 Case import failed: #{inspect(error)}")
        {:error, error}
    end
  end

  defp is_notice_record?(record) do
    fields = record["fields"] || %{}
    action_type = fields["offence_action_type"] || ""
    String.contains?(action_type, "Notice")
  end

  defp is_case_record?(record) do
    fields = record["fields"] || %{}
    action_type = fields["offence_action_type"] || ""
    action_type in ["Court Case", "Caution"]
  end

  defp import_case_batch(records, actor) do
    results = Enum.map(records, fn record ->
      case import_single_case(record, actor) do
        {:ok, _case} -> :ok
        {:error, error} -> 
          fields = record["fields"] || %{}
          Logger.error("Failed to import case #{fields["regulator_id"]}: #{inspect(error)}")
          :error
      end
    end)
    
    imported_count = Enum.count(results, &(&1 == :ok))
    error_count = Enum.count(results, &(&1 == :error))
    
    {:ok, %{imported: imported_count, errors: error_count}}
  end

  defp import_notice_batch(records, actor) do
    results = Enum.map(records, fn record ->
      case import_single_notice(record, actor) do
        {:ok, _notice} -> :ok
        {:error, error} -> 
          fields = record["fields"] || %{}
          Logger.error("Failed to import notice #{fields["regulator_id"]}: #{inspect(error)}")
          :error
      end
    end)
    
    imported_count = Enum.count(results, &(&1 == :ok))
    error_count = Enum.count(results, &(&1 == :error))
    
    {:ok, %{imported: imported_count, errors: error_count}}
  end

  defp import_single_case(record, _actor) do
    fields = record["fields"] || %{}
    
    attrs = %{
      agency_code: String.to_atom(fields["agency_code"] || "hse"),
      regulator_id: to_string(fields["regulator_id"]),
      offender_attrs: %{
        name: fields["offender_name"],
        postcode: fields["offender_postcode"],
        local_authority: fields["offender_local_authority"],
        main_activity: fields["offender_main_activity"]
      },
      offence_action_type: fields["offence_action_type"],
      offence_action_date: parse_date(fields["offence_action_date"]),
      offence_hearing_date: parse_date(fields["offence_hearing_date"]),
      offence_result: fields["offence_result"],
      offence_fine: parse_decimal(fields["offence_fine"]),
      offence_costs: parse_decimal(fields["offence_costs"]),
      offence_breaches: fields["offence_breaches"],
      offence_breaches_clean: fields["offence_breaches_clean"],
      regulator_function: fields["regulator_function"],
      regulator_url: fields["regulator_url"],
      related_cases: fields["related_cases"]
    }
    
    EhsEnforcement.Enforcement.create_case(attrs)
  end

  defp import_single_notice(record, _actor) do
    fields = record["fields"] || %{}
    
    attrs = %{
      agency_code: String.to_atom(fields["agency_code"] || "hse"),
      regulator_id: to_string(fields["regulator_id"]),
      offender_attrs: %{
        name: fields["offender_name"],
        postcode: fields["offender_postcode"],
        local_authority: fields["offender_local_authority"],
        main_activity: fields["offender_main_activity"]
      },
      offence_action_type: fields["offence_action_type"],
      offence_action_date: parse_date(fields["offence_action_date"]),
      notice_date: parse_date(fields["notice_date"]),
      operative_date: parse_date(fields["operative_date"]),
      compliance_date: parse_date(fields["compliance_date"]),
      notice_body: fields["notice_body"],
      offence_breaches: fields["offence_breaches"]
    }
    
    EhsEnforcement.Enforcement.create_notice(attrs)
  end

  defp parse_date(nil), do: nil
  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end
  defp parse_date(_), do: nil

  defp parse_decimal(nil), do: nil
  defp parse_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> decimal
      _ -> nil
    end
  end
  defp parse_decimal(value) when is_integer(value) do
    Decimal.new(value)
  end
  defp parse_decimal(value) when is_float(value) do
    Decimal.from_float(value)
  end
  defp parse_decimal(_), do: nil

  defp count_notices do
    case EhsEnforcement.Enforcement.list_notices() do
      {:ok, notices} -> {:ok, length(notices)}
      {:error, error} -> {:error, error}
    end
  end

  defp count_cases do
    case EhsEnforcement.Enforcement.list_cases() do
      {:ok, cases} -> {:ok, length(cases)}
      {:error, error} -> {:error, error}
    end
  end

  defp count_recent_notice_imports do
    # This would query sync logs for recent notice imports
    # For now, return a placeholder
    {:ok, 0}
  end

  defp count_recent_case_imports do
    # This would query sync logs for recent case imports
    # For now, return a placeholder
    {:ok, 0}
  end

  defp calculate_import_error_rate do
    # This would calculate error rate from sync logs
    # For now, return a placeholder
    {:ok, 0.0}
  end

  defp count_orphaned_offenders do
    orphaned_query = """
      SELECT COUNT(*) as orphaned_count
      FROM offenders o
      WHERE NOT EXISTS (
        SELECT 1 FROM cases c WHERE c.offender_id = o.id
      ) AND NOT EXISTS (
        SELECT 1 FROM notices n WHERE n.offender_id = o.id
      )
    """
    
    case EhsEnforcement.Repo.query(orphaned_query) do
      {:ok, %{rows: [[count]]}} -> {:ok, count}
      {:error, error} -> {:error, error}
    end
  end

  defp do_cleanup_orphaned_offenders(true, _actor) do
    # Dry run - don't actually delete
    {:ok, 0}
  end

  defp do_cleanup_orphaned_offenders(false, _actor) do
    # Delete orphaned offenders using direct SQL for efficiency
    delete_query = """
      DELETE FROM offenders o
      WHERE NOT EXISTS (
        SELECT 1 FROM cases c WHERE c.offender_id = o.id
      ) AND NOT EXISTS (
        SELECT 1 FROM notices n WHERE n.offender_id = o.id
      )
    """
    
    case EhsEnforcement.Repo.query(delete_query) do
      {:ok, %{num_rows: deleted_count}} ->
        Logger.info("🗑️ Deleted #{deleted_count} orphaned offenders")
        {:ok, deleted_count}
        
      {:error, error} ->
        {:error, error}
    end
  end
end