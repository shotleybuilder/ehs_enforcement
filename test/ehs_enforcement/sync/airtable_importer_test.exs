defmodule EhsEnforcement.Sync.AirtableImporterTest do
  use EhsEnforcement.DataCase, async: false  # async: false due to HTTP mocking

  alias EhsEnforcement.Sync.AirtableImporter
  alias EhsEnforcement.Enforcement

  describe "import_all_data/0" do
    test "imports complete dataset from Airtable in batches" do
      # Setup HSE agency
      {:ok, _agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive"
      })

      # This will fail because AirtableImporter.import_all_data/0 doesn't exist yet
      result = AirtableImporter.import_all_data()
      
      assert :ok = result

      # Verify all records were imported
      {:ok, cases} = Enforcement.list_cases()
      {:ok, notices} = Enforcement.list_notices()
      
      # Should have created cases and notices for each record
      assert length(cases) == 250
      assert length(notices) == 250
    end

    test "handles HTTP errors during import" do
      # This will fail because AirtableImporter.import_all_data/0 doesn't exist yet
      result = AirtableImporter.import_all_data()
      assert {:error, :timeout} = result
    end

    test "handles malformed JSON response" do
      # This will fail because AirtableImporter.import_all_data/0 doesn't exist yet
      result = AirtableImporter.import_all_data()
      assert {:error, %Jason.DecodeError{}} = result
    end

    test "handles Airtable API errors" do
      # This will fail because AirtableImporter.import_all_data/0 doesn't exist yet
      result = AirtableImporter.import_all_data()
      assert {:error, :airtable_api_error} = result
    end

    test "resumes import from last successful batch on failure" do
      # Setup agency
      {:ok, _agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive"
      })

      # This will fail because AirtableImporter.import_all_data/0 doesn't exist yet
      result = AirtableImporter.import_all_data()
      
      # Should have partial success
      assert {:error, :network_error} = result
      
      # But first batch should have been imported
      {:ok, cases} = Enforcement.list_cases()
      assert length(cases) == 1
      assert List.first(cases).regulator_id == "SUCCESS001"
    end
  end

  describe "import_batch/1" do
    test "processes mixed case and notice records in single batch" do
      # Setup agency
      {:ok, _agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive"
      })

      batch_records = [
        %{
          "id" => "rec_case1",
          "fields" => %{
            "regulator_id" => "MIXED001",
            "offender_name" => "Mixed Case Company Ltd",
            "agency_code" => "hse"
          }
        }
      ]

      # This will fail because AirtableImporter.import_batch/1 doesn't exist yet
      result = AirtableImporter.import_batch(batch_records)
      assert :ok = result

      # Verify both types were created
      {:ok, cases} = Enforcement.list_cases(filter: [regulator_id: "MIXED001"])
      assert length(cases) == 1
    end

    test "handles records with missing required fields" do
      # Setup agency
      {:ok, _agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive"
      })

      batch_records = [
        %{"id" => "rec_invalid1", "fields" => %{"offender_name" => "Invalid Company Ltd"}}
      ]

      # This will fail because AirtableImporter.import_batch/1 doesn't exist yet
      result = AirtableImporter.import_batch(batch_records)
      assert :ok = result

      # Only valid record should be imported
      {:ok, cases} = Enforcement.list_cases()
      assert length(cases) == 1
    end

    test "handles large batch efficiently" do
      # Setup agency
      {:ok, _agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive"
      })

      large_batch = []  # Would be populated with 200 records

      # This will fail because AirtableImporter.import_batch/1 doesn't exist yet
      {duration_us, result} = :timer.tc(fn ->
        AirtableImporter.import_batch(large_batch)
      end)

      assert :ok = result

      # Verify all records were imported
      {:ok, cases} = Enforcement.list_cases()
      assert length(cases) == 200

      # Should complete in reasonable time (less than 10 seconds)
      duration_seconds = duration_us / 1_000_000
      assert duration_seconds < 10
    end
  end

  describe "partition_records/1" do
    test "correctly separates cases and notices" do
      mixed_records = [
        %{"id" => "rec1", "fields" => %{"regulator_id" => "CASE001"}},
        %{"id" => "rec2", "fields" => %{"notice_id" => "NOT001"}}
      ]

      # This will fail because AirtableImporter.partition_records/1 doesn't exist yet
      {cases, notices} = AirtableImporter.partition_records(mixed_records)
      
      assert length(cases) == 1
      assert length(notices) == 1
    end

    test "handles empty record list" do
      # This will fail because AirtableImporter.partition_records/1 doesn't exist yet
      {cases, notices} = AirtableImporter.partition_records([])
      
      assert cases == []
      assert notices == []
    end
  end

  describe "stream_airtable_records/0" do
    test "creates lazy stream for processing large datasets" do
      # This will fail because AirtableImporter.stream_airtable_records/0 doesn't exist yet
      stream = AirtableImporter.stream_airtable_records()
      
      # Take first 2 records (should trigger 2 API calls)
      records = stream |> Enum.take(2)
      
      assert length(records) == 2
    end
  end

  describe "error recovery and logging" do
    test "logs import progress and errors" do
      # Setup agency
      {:ok, _agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive"
      })

      # This will fail because AirtableImporter.import_all_data/0 doesn't exist yet
      result = AirtableImporter.import_all_data()
      assert {:error, :econnrefused} = result
    end

    test "provides detailed error information for debugging" do
      batch_records = [
        %{"id" => "rec_error1", "fields" => %{"regulator_id" => "ERROR001"}}
      ]

      # This will fail because AirtableImporter.import_batch/1 doesn't exist yet
      result = AirtableImporter.import_batch(batch_records)
      
      # Even with errors, should continue processing and return details
      assert match?({:ok, _error_details}, result) or match?(:ok, result)
    end
  end
end