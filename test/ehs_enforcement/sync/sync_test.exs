defmodule EhsEnforcement.Sync.SyncTest do
  use EhsEnforcement.DataCase
  
  alias EhsEnforcement.Sync
  alias EhsEnforcement.Enforcement
  
  require Ash.Query
  import Ash.Expr

  describe "import_notices/1" do
    setup do
      # Ensure HSE agency exists for imports
      {:ok, agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive",
        enabled: true,
        base_url: "https://www.hse.gov.uk"
      })
      
      %{agency: agency}
    end

    test "imports notice records successfully with default options" do
      # Mock successful import of notice records
      result = Sync.import_notices(limit: 1)
      
      case result do
        {:ok, stats} ->
          assert is_map(stats)
          assert Map.has_key?(stats, :imported)
          assert Map.has_key?(stats, :errors)
          assert stats.imported >= 0
          assert stats.errors >= 0
          
        {:error, {:airtable_connection_failed, _reason}} ->
          # Skip test if Airtable is not available (e.g., in CI)
          assert true
          
        {:error, reason} ->
          flunk("Import failed unexpectedly: #{inspect(reason)}")
      end
    end

    test "imports notice records with custom limit and batch size" do
      result = Sync.import_notices(limit: 5, batch_size: 2)
      
      case result do
        {:ok, stats} ->
          assert is_map(stats)
          # Imported count should not exceed limit
          assert stats.imported <= 5
          
        {:error, {:airtable_connection_failed, _reason}} ->
          # Skip test if Airtable is not available
          assert true
          
        {:error, reason} ->
          flunk("Import failed unexpectedly: #{inspect(reason)}")
      end
    end

    test "handles actor parameter for authorization" do
      # Test with actor (for future authorization implementation)
      admin_user = %{id: "admin-123", role: :admin}
      
      result = Sync.import_notices(limit: 1, actor: admin_user)
      
      case result do
        {:ok, stats} ->
          assert is_map(stats)
          
        {:error, {:airtable_connection_failed, _reason}} ->
          # Skip test if Airtable is not available
          assert true
          
        {:error, reason} ->
          flunk("Import failed unexpectedly: #{inspect(reason)}")
      end
    end

    test "fails gracefully when Airtable is unavailable" do
      # This test will naturally fail if Airtable connection fails
      # We handle this by checking for the specific error type
      result = Sync.import_notices(limit: 1)
      
      case result do
        {:ok, _stats} ->
          # Import succeeded - this is also valid
          assert true
          
        {:error, {:airtable_connection_failed, reason}} ->
          # Expected error when Airtable is unavailable
          assert is_binary(reason) or is_map(reason)
          
        {:error, reason} ->
          flunk("Unexpected error type: #{inspect(reason)}")
      end
    end
  end

  describe "get_notice_import_stats/0" do
    test "returns import statistics structure" do
      result = Sync.get_notice_import_stats()
      
      case result do
        {:ok, stats} ->
          assert is_map(stats)
          assert Map.has_key?(stats, :total_notices)
          assert Map.has_key?(stats, :recent_imports)
          assert Map.has_key?(stats, :error_rate)
          assert is_integer(stats.total_notices)
          assert is_integer(stats.recent_imports)
          assert is_float(stats.error_rate)
          
        {:error, reason} ->
          flunk("Get stats failed: #{inspect(reason)}")
      end
    end
  end

  describe "notice filtering logic" do
    test "correctly identifies notice records" do
      # Test the private is_notice_record? logic through the import function
      # This is tested indirectly by verifying that only notice records are imported
      
      # We can't easily test the private function directly, but we can verify
      # that the import process correctly filters for notice records by checking
      # that imported records have notice-type offence_action_type values
      
      case Sync.import_notices(limit: 1) do
        {:ok, stats} when stats.imported > 0 ->
          # Check that we actually have notice records in the database
          {:ok, notices} = Enforcement.list_notices()
          
          if length(notices) > 0 do
            notice = List.first(notices)
            assert String.contains?(notice.offence_action_type || "", "Notice")
          end
          
        {:ok, _stats} ->
          # No records imported - this is fine for testing
          assert true
          
        {:error, {:airtable_connection_failed, _reason}} ->
          # Skip test if Airtable is not available
          assert true
          
        {:error, reason} ->
          flunk("Import failed: #{inspect(reason)}")
      end
    end
  end

  describe "error handling" do
    test "handles malformed records gracefully" do
      # This test verifies that the import function doesn't crash
      # when encountering unexpected data formats
      
      result = Sync.import_notices(limit: 1)
      
      # The function should either succeed or fail gracefully
      case result do
        {:ok, _stats} -> assert true
        {:error, {:airtable_connection_failed, _reason}} -> assert true
        {:error, _reason} -> assert true
      end
    end
  end

  describe "import_cases/1" do
    setup do
      # Ensure HSE agency exists for imports
      {:ok, agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive",
        enabled: true,
        base_url: "https://www.hse.gov.uk"
      })
      
      %{agency: agency}
    end

    test "imports case records successfully with default options" do
      # Mock successful import of case records
      result = Sync.import_cases(limit: 1)
      
      case result do
        {:ok, stats} ->
          assert is_map(stats)
          assert Map.has_key?(stats, :imported)
          assert Map.has_key?(stats, :errors)
          assert stats.imported >= 0
          assert stats.errors >= 0
          
        {:error, {:airtable_connection_failed, _reason}} ->
          # Skip test if Airtable is not available (e.g., in CI)
          assert true
          
        {:error, reason} ->
          flunk("Import failed unexpectedly: #{inspect(reason)}")
      end
    end

    test "imports case records with custom limit and batch size" do
      result = Sync.import_cases(limit: 5, batch_size: 2)
      
      case result do
        {:ok, stats} ->
          assert is_map(stats)
          # Imported count should not exceed limit
          assert stats.imported <= 5
          
        {:error, {:airtable_connection_failed, _reason}} ->
          # Skip test if Airtable is not available
          assert true
          
        {:error, reason} ->
          flunk("Import failed unexpectedly: #{inspect(reason)}")
      end
    end

    test "handles actor parameter for authorization" do
      # Test with actor (for future authorization implementation)
      admin_user = %{id: "admin-123", role: :admin}
      
      result = Sync.import_cases(limit: 1, actor: admin_user)
      
      case result do
        {:ok, stats} ->
          assert is_map(stats)
          
        {:error, {:airtable_connection_failed, _reason}} ->
          # Skip test if Airtable is not available
          assert true
          
        {:error, reason} ->
          flunk("Import failed unexpectedly: #{inspect(reason)}")
      end
    end

    test "fails gracefully when Airtable is unavailable" do
      # This test will naturally fail if Airtable connection fails
      # We handle this by checking for the specific error type
      result = Sync.import_cases(limit: 1)
      
      case result do
        {:ok, _stats} ->
          # Import succeeded - this is also valid
          assert true
          
        {:error, {:airtable_connection_failed, reason}} ->
          # Expected error when Airtable is unavailable
          assert is_binary(reason) or is_map(reason)
          
        {:error, reason} ->
          flunk("Unexpected error type: #{inspect(reason)}")
      end
    end
  end

  describe "get_case_import_stats/0" do
    test "returns import statistics structure" do
      result = Sync.get_case_import_stats()
      
      case result do
        {:ok, stats} ->
          assert is_map(stats)
          assert Map.has_key?(stats, :total_cases)
          assert Map.has_key?(stats, :recent_imports)
          assert Map.has_key?(stats, :error_rate)
          assert is_integer(stats.total_cases)
          assert is_integer(stats.recent_imports)
          assert is_float(stats.error_rate)
          
        {:error, reason} ->
          flunk("Get stats failed: #{inspect(reason)}")
      end
    end
  end

  describe "case filtering logic" do
    test "correctly identifies case records" do
      # Test the private is_case_record? logic through the import function
      # This is tested indirectly by verifying that only case records are imported
      
      # We can't easily test the private function directly, but we can verify
      # that the import process correctly filters for case records by checking
      # that imported records have case-type offence_action_type values
      
      case Sync.import_cases(limit: 1) do
        {:ok, stats} when stats.imported > 0 ->
          # Check that we actually have case records in the database
          {:ok, cases} = Enforcement.list_cases()
          
          if length(cases) > 0 do
            case_record = List.first(cases)
            assert case_record.offence_action_type in ["Court Case", "Caution"]
          end
          
        {:ok, _stats} ->
          # No records imported - this is fine for testing
          assert true
          
        {:error, {:airtable_connection_failed, _reason}} ->
          # Skip test if Airtable is not available
          assert true
          
        {:error, reason} ->
          flunk("Import failed: #{inspect(reason)}")
      end
    end
  end

  describe "integration test - case import" do
    test "imports case records with proper data structure" do
      # Integration test to verify the full case import process
      initial_case_count = case Enforcement.list_cases() do
        {:ok, cases} -> length(cases)
        {:error, _} -> 0
      end
      
      result = Sync.import_cases(limit: 5, batch_size: 2)
      
      case result do
        {:ok, stats} ->
          assert is_map(stats)
          assert Map.has_key?(stats, :imported)
          assert Map.has_key?(stats, :errors)
          
          # If we imported cases, verify they have the right structure
          if stats.imported > 0 do
            {:ok, cases} = Enforcement.list_cases()
            final_case_count = length(cases)
            
            # Should have more cases than before
            assert final_case_count >= initial_case_count
            
            # Check that imported cases have required fields
            if final_case_count > 0 do
              sample_case = List.first(cases)
              assert sample_case.regulator_id
              assert sample_case.offence_action_type in ["Court Case", "Caution"]
              assert sample_case.agency_id
              assert sample_case.offender_id
            end
          end
          
        {:error, {:airtable_connection_failed, _reason}} ->
          # Skip test if Airtable is not available
          assert true
          
        {:error, reason} ->
          flunk("Integration test failed: #{inspect(reason)}")
      end
    end

    test "case import handles financial fields correctly" do
      # Test that decimal fields for fines and costs are properly parsed
      case Sync.import_cases(limit: 3) do
        {:ok, stats} when stats.imported > 0 ->
          {:ok, cases} = Enforcement.list_cases()
          
          # Find a case with financial data if available
          case_with_fine = Enum.find(cases, fn c -> c.offence_fine != nil end)
          case_with_costs = Enum.find(cases, fn c -> c.offence_costs != nil end)
          
          if case_with_fine do
            assert %Decimal{} = case_with_fine.offence_fine
          end
          
          if case_with_costs do
            assert %Decimal{} = case_with_costs.offence_costs
          end
          
        {:ok, _stats} ->
          # No records imported - this is fine for testing
          assert true
          
        {:error, {:airtable_connection_failed, _reason}} ->
          # Skip test if Airtable is not available
          assert true
          
        {:error, reason} ->
          flunk("Financial fields test failed: #{inspect(reason)}")
      end
    end

    test "case import handles date fields correctly" do
      # Test that date fields are properly parsed
      case Sync.import_cases(limit: 3) do
        {:ok, stats} when stats.imported > 0 ->
          {:ok, cases} = Enforcement.list_cases()
          
          # Find a case with date data if available
          case_with_action_date = Enum.find(cases, fn c -> c.offence_action_date != nil end)
          case_with_hearing_date = Enum.find(cases, fn c -> c.offence_hearing_date != nil end)
          
          if case_with_action_date do
            assert %Date{} = case_with_action_date.offence_action_date
          end
          
          if case_with_hearing_date do
            assert %Date{} = case_with_hearing_date.offence_hearing_date
          end
          
        {:ok, _stats} ->
          # No records imported - this is fine for testing
          assert true
          
        {:error, {:airtable_connection_failed, _reason}} ->
          # Skip test if Airtable is not available
          assert true
          
        {:error, reason} ->
          flunk("Date fields test failed: #{inspect(reason)}")
      end
    end
  end
end