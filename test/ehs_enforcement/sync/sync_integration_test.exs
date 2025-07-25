defmodule EhsEnforcement.Sync.SyncIntegrationTest do
  use EhsEnforcement.DataCase, async: false  # async: false due to GenServer and HTTP mocking

  alias EhsEnforcement.Sync.{SyncManager, OffenderMatcher, SyncWorker, AirtableImporter}
  alias EhsEnforcement.Enforcement

  setup do
    # Create HSE agency for all tests
    {:ok, agency} = Enforcement.create_agency(%{
      code: :hse,
      name: "Health and Safety Executive"
    })
    
    {:ok, agency: agency}
  end

  describe "complete sync workflow" do
    test "end-to-end airtable import to postgres via ash resources", %{agency: _agency} do
      # This will fail because AirtableImporter.import_all_data/0 doesn't exist yet
      result = AirtableImporter.import_all_data()
      assert :ok = result

      # Verify data integrity and relationships
      {:ok, cases} = Enforcement.list_cases(load: [:offender, :agency])
      {:ok, notices} = Enforcement.list_notices(load: [:offender, :agency])
      {:ok, offenders} = Enforcement.list_offenders()

      # Should have 2 cases, 1 notice, 2 unique offenders
      assert length(cases) == 2
      assert length(notices) == 1
      assert length(offenders) == 2

      # Verify case data and relationships
      case1 = Enum.find(cases, &(&1.regulator_id == "E2E001"))
      case2 = Enum.find(cases, &(&1.regulator_id == "E2E002"))
      
      assert case1.agency.code == :hse
      assert case1.offender.name == "e2e test company limited"
      assert case1.offence_fine == Decimal.new("15000.00")
      
      assert case2.agency.code == :hse
      assert case2.offender.name == "e2e test company limited"
      assert case2.offence_fine == Decimal.new("8000.00")
      
      # Both cases should reference the same offender (deduplication worked)
      assert case1.offender_id == case2.offender_id
    end

    test "sync worker processes jobs and updates database", %{agency: _agency} do
      # Create and process sync jobs
      case_job = %{args: %{"agency" => "hse", "type" => "cases"}}
      notice_job = %{args: %{"agency" => "hse", "type" => "notices"}}

      # This will fail because SyncWorker.perform/1 doesn't exist yet
      assert :ok = SyncWorker.perform(case_job)
      assert :ok = SyncWorker.perform(notice_job)

      # Verify data was created directly in PostgreSQL
      {:ok, cases} = Enforcement.list_cases(load: [:offender, :agency])
      {:ok, notices} = Enforcement.list_notices(load: [:offender, :agency])

      assert length(cases) == 1
      assert length(notices) == 1

      case = List.first(cases)
      notice = List.first(notices)

      assert case.regulator_id == "WORKER_E2E001"
      assert case.offender.name == "worker e2e company limited"
      assert case.agency.code == :hse

      assert notice.notice_id == "WORKER_NOT001"
      assert notice.offender.name == "worker notice co limited"
      assert notice.notice_type == :prohibition
    end

    test "offender matching works across different sync methods", %{agency: _agency} do
      # This will fail because AirtableImporter.import_all_data/0 doesn't exist yet
      assert :ok = AirtableImporter.import_all_data()

      # Verify initial offender was created
      {:ok, offenders_after_import} = Enforcement.list_offenders()
      assert length(offenders_after_import) == 1
      initial_offender = List.first(offenders_after_import)
      assert initial_offender.name == "matching test company limited"

      # This will fail because SyncWorker.perform/1 doesn't exist yet
      job = %{args: %{"agency" => "hse", "type" => "cases"}}
      assert :ok = SyncWorker.perform(job)

      # Verify we still have only 1 offender (matching worked)
      {:ok, final_offenders} = Enforcement.list_offenders()
      assert length(final_offenders) == 1

      # But should have 2 cases
      {:ok, cases} = Enforcement.list_cases(load: [:offender])
      assert length(cases) == 2

      # Both cases should reference the same offender
      offender_ids = Enum.map(cases, & &1.offender_id) |> Enum.uniq()
      assert length(offender_ids) == 1

      # Verify offender statistics were updated
      final_offender = List.first(final_offenders)
      assert final_offender.total_cases == 2
      assert Decimal.equal?(final_offender.total_fines, Decimal.new("12500.00"))  # 5000 + 7500
    end

    test "handles mixed success and failure scenarios gracefully", %{agency: _agency} do
      # This will fail because AirtableImporter.import_all_data/0 doesn't exist yet
      result = AirtableImporter.import_all_data()
      assert :ok = result  # Should succeed overall

      # Valid records should have been imported
      {:ok, cases} = Enforcement.list_cases()
      {:ok, notices} = Enforcement.list_notices()
      
      assert length(cases) == 1  # Only valid case
      assert length(notices) == 1  # Valid notice
      
      case = List.first(cases)
      notice = List.first(notices)
      
      assert case.regulator_id == "MIXED_VALID001"
      assert notice.notice_id == "MIXED_NOT001"
    end

    test "performance with large dataset sync", %{agency: _agency} do
      # This will fail because AirtableImporter.import_all_data/0 doesn't exist yet
      {duration_us, result} = :timer.tc(fn ->
        AirtableImporter.import_all_data()
      end)

      assert :ok = result

      # Verify all records were imported
      {:ok, cases} = Enforcement.list_cases()
      assert length(cases) == 500

      # Should complete in reasonable time (less than 30 seconds for 500 records)
      duration_seconds = duration_us / 1_000_000
      assert duration_seconds < 30

      # Verify data integrity on a sample
      sample_case = Enum.find(cases, &(&1.regulator_id == "PERF0001"))
      assert sample_case != nil
      assert sample_case.offence_fine == Decimal.new("1100.00")  # 1000 + 1*100
    end

    test "maintains data consistency during concurrent operations", %{agency: _agency} do
      # Run both operations concurrently
      task1 = Task.async(fn -> AirtableImporter.import_all_data() end)
      task2 = Task.async(fn -> 
        job = %{args: %{"agency" => "hse", "type" => "cases"}}
        SyncWorker.perform(job)
      end)

      # This will fail because the modules don't exist yet
      result1 = Task.await(task1)
      result2 = Task.await(task2)

      assert :ok = result1
      assert :ok = result2

      # Verify data consistency
      {:ok, cases} = Enforcement.list_cases()
      {:ok, offenders} = Enforcement.list_offenders()

      # Should have 2 cases but only 1 offender
      assert length(cases) == 2
      assert length(offenders) == 1

      # Both cases should reference the same offender
      offender_ids = Enum.map(cases, & &1.offender_id) |> Enum.uniq()
      assert length(offender_ids) == 1

      # Verify offender statistics are correct
      offender = List.first(offenders)
      assert offender.total_cases == 2
      assert Decimal.equal?(offender.total_fines, Decimal.new("10000.00"))  # 4000 + 6000
    end
  end

  describe "error recovery and resilience" do
    test "recovers from partial failures and maintains system state", %{agency: _agency} do
      batch_with_errors = [
        %{"id" => "rec_valid", "fields" => %{"regulator_id" => "RECOVERY001"}},
        %{"id" => "rec_invalid", "fields" => %{"regulator_id" => "RECOVERY002"}}
      ]

      # This will fail because AirtableImporter.import_batch/1 doesn't exist yet
      result = AirtableImporter.import_batch(batch_with_errors)
      assert :ok = result  # Should handle errors gracefully

      # Verify valid records were processed
      {:ok, cases} = Enforcement.list_cases()
      assert length(cases) == 1  # Only valid record
      
      case = List.first(cases)
      assert case.regulator_id == "RECOVERY001"
      
      # System should remain in consistent state
      {:ok, offenders} = Enforcement.list_offenders()
      assert length(offenders) == 1
    end

    test "handles network errors during sync with proper error reporting", %{agency: _agency} do
      # This will fail because AirtableImporter.import_all_data/0 doesn't exist yet
      result = AirtableImporter.import_all_data()
      assert {:error, :timeout} = result

      # System should remain clean (no partial data)
      {:ok, cases} = Enforcement.list_cases()
      {:ok, offenders} = Enforcement.list_offenders()
      
      assert length(cases) == 0
      assert length(offenders) == 0
    end
  end
end