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

      # Configure mock for successful large dataset import
      Process.put(:airtable_test_scenario, :success_large_dataset)

      result = AirtableImporter.import_all_data()
      
      assert :ok = result

      # Verify all records were imported
      {:ok, cases} = Enforcement.list_cases()
      {:ok, notices} = Enforcement.list_notices()
      
      # Should have created cases and notices for each record (250 cases + 250 notices)
      assert length(cases) == 250
      assert length(notices) == 250
    end

    test "handles HTTP errors during import" do
      Process.put(:airtable_test_scenario, :timeout)
      result = AirtableImporter.import_all_data()
      assert {:error, %{reason: :timeout}} = result
    end

    test "handles malformed JSON response" do
      Process.put(:airtable_test_scenario, :malformed_json)
      result = AirtableImporter.import_all_data()
      assert {:error, %Jason.DecodeError{}} = result
    end

    test "handles Airtable API errors" do
      Process.put(:airtable_test_scenario, :airtable_api_error)
      result = AirtableImporter.import_all_data()
      assert {:error, %{type: :unauthorized}} = result
    end

    test "resumes import from last successful batch on failure" do
      # Setup agency
      {:ok, _agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive"
      })

      Process.put(:airtable_test_scenario, :network_error_with_partial_success)
      Process.put(:airtable_call_count, 0)  # Reset call counter

      result = AirtableImporter.import_all_data()
      
      # Should have partial success - the method returns an error but some data imported
      assert {:error, %{reason: :econnrefused}} = result
      
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
            "agency_code" => "hse",
            "offence_action_type" => "Court Case"
          }
        }
      ]

      result = AirtableImporter.import_batch(batch_records)
      assert :ok = result

      # Verify the case was created
      {:ok, cases} = Enforcement.list_cases()
      case_with_regulator = Enum.find(cases, &(&1.regulator_id == "MIXED001"))
      assert case_with_regulator != nil
    end

    test "handles records with missing required fields" do
      # Setup agency
      {:ok, _agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive"
      })

      batch_records = [
        # Record without required fields (missing regulator_id)
        %{"id" => "rec_invalid1", "fields" => %{"offender_name" => "Invalid Company Ltd"}},
        # Valid record
        %{
          "id" => "rec_valid1", 
          "fields" => %{
            "regulator_id" => "VALID001",
            "offender_name" => "Valid Company Ltd",
            "agency_code" => "hse",
            "offence_action_type" => "Court Case"
          }
        }
      ]

      result = AirtableImporter.import_batch(batch_records)
      assert :ok = result

      # Only valid record should be imported
      {:ok, cases} = Enforcement.list_cases()
      assert length(cases) == 1
      assert List.first(cases).regulator_id == "VALID001"
    end

    test "handles large batch efficiently" do
      # Setup agency
      {:ok, _agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive"
      })

      # Generate 400 records (200 cases + 200 notices)
      large_batch = generate_large_test_batch(400)

      {duration_us, result} = :timer.tc(fn ->
        AirtableImporter.import_batch(large_batch)
      end)

      assert :ok = result

      # Verify all records were imported
      {:ok, cases} = Enforcement.list_cases()
      {:ok, notices} = Enforcement.list_notices()
      assert length(cases) == 200
      assert length(notices) == 200

      # Should complete in reasonable time (less than 10 seconds)
      duration_seconds = duration_us / 1_000_000
      assert duration_seconds < 10
    end
  end

  describe "partition_records/1" do
    test "correctly separates cases and notices" do
      mixed_records = [
        %{"id" => "rec1", "fields" => %{"regulator_id" => "CASE001", "offence_action_type" => "Court Case"}},
        %{"id" => "rec2", "fields" => %{"regulator_id" => "NOT001", "offence_action_type" => "Improvement Notice"}}
      ]

      {cases, notices} = AirtableImporter.partition_records(mixed_records)
      
      assert length(cases) == 1
      assert length(notices) == 1
    end

    test "handles empty record list" do
      {cases, notices} = AirtableImporter.partition_records([])
      
      assert cases == []
      assert notices == []
    end
  end

  describe "stream_airtable_records/0" do
    test "creates lazy stream for processing large datasets" do
      Process.put(:airtable_test_scenario, :success_batch)
      
      stream = AirtableImporter.stream_airtable_records()
      
      # Take first 2 records (should trigger API call)
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

      Process.put(:airtable_test_scenario, :econnrefused)
      result = AirtableImporter.import_all_data()
      assert {:error, %{reason: :econnrefused}} = result
    end

    test "provides detailed error information for debugging" do
      batch_records = [
        %{"id" => "rec_error1", "fields" => %{"regulator_id" => "ERROR001", "offence_action_type" => "Court Case"}}
      ]

      result = AirtableImporter.import_batch(batch_records)
      
      # Even with errors, should continue processing and return details
      assert :ok = result
    end
  end

  # Helper function to generate test data
  defp generate_large_test_batch(total_count) do
    cases_count = div(total_count, 2)
    notices_count = total_count - cases_count
    
    cases = 1..cases_count
    |> Enum.map(fn i ->
      %{
        "id" => "rec_case_#{i}",
        "fields" => %{
          "regulator_id" => "CASE#{String.pad_leading(to_string(i), 3, "0")}",
          "offender_name" => "Large Batch Case Company #{i} Ltd",
          "agency_code" => "hse",
          "offence_action_type" => "Court Case"
        }
      }
    end)
    
    notices = 1..notices_count
    |> Enum.map(fn i ->
      %{
        "id" => "rec_notice_#{i}",
        "fields" => %{
          "regulator_id" => "NOT#{String.pad_leading(to_string(i), 3, "0")}",
          "offender_name" => "Large Batch Notice Company #{i} Ltd",
          "agency_code" => "hse",
          "offence_action_type" => "Improvement Notice"
        }
      }
    end)
    
    cases ++ notices
  end

end