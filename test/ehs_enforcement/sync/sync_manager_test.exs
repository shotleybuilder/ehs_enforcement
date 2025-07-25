defmodule EhsEnforcement.Sync.SyncManagerTest do
  use EhsEnforcement.DataCase, async: false  # async: false due to Application env

  alias EhsEnforcement.Sync.SyncManager
  alias EhsEnforcement.Enforcement

  setup do
    # Use mock client for testing
    Application.put_env(:ehs_enforcement, :airtable_client, EhsEnforcement.Test.MockAirtableClient)
    Application.put_env(:ehs_enforcement, :mock_scraping, true)
    
    on_exit(fn ->
      Application.delete_env(:ehs_enforcement, :airtable_client)
      Application.delete_env(:ehs_enforcement, :mock_scraping)
    end)
    
    :ok
  end

  describe "sync manager" do
    test "imports data from airtable using ash bulk actions" do
      # Create HSE agency first
      {:ok, _agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive"
      })

      # This will fail because SyncManager.import_from_airtable/0 doesn't exist
      result = SyncManager.import_from_airtable()
      
      assert {:ok, results} = result
      assert length(results) == 2

      # Verify cases were created with proper relationships
      {:ok, cases} = Enforcement.list_cases(load: [:offender, :agency])
      assert length(cases) == 2

      case1 = Enum.find(cases, &(&1.regulator_id == "HSE001"))
      assert case1.offender.name == "test company limited"  # normalized
      assert case1.agency.code == :hse
      assert case1.offence_fine == Decimal.new("5000.00")
    end

    test "handles import errors gracefully" do
      # Temporarily set mock to return error
      Application.put_env(:ehs_enforcement, :airtable_client, EhsEnforcement.Test.ErrorAirtableClient)
      
      result = SyncManager.import_from_airtable()
      assert {:error, _} = result
    end

    test "syncs agency data directly to postgres" do
      # Setup
      {:ok, agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive"
      })

      # This will fail because SyncManager.sync_agency/2 doesn't exist yet
      result = SyncManager.sync_agency(:hse, :cases)
      
      assert :ok = result

      # Verify case was created
      {:ok, cases} = Enforcement.list_cases(
        filter: [regulator_id: "HSE123"],
        load: [:offender, :agency]
      )
      
      assert length(cases) == 1
      case = List.first(cases)
      assert case.offender.name == "direct import co limited"
      assert case.agency.code == :hse
    end

    test "syncs notice data directly to postgres" do
      # Setup
      {:ok, agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive"
      })

      # This will fail because SyncManager.sync_agency/2 doesn't exist yet
      result = SyncManager.sync_agency(:hse, :notices)
      
      assert :ok = result

      # Verify notice was created
      {:ok, notices} = Enforcement.list_notices(
        filter: [notice_id: "NOT001"],
        load: [:offender, :agency]
      )
      
      assert length(notices) == 1
      notice = List.first(notices)
      assert notice.offender.name == "notice company limited"
      assert notice.agency.code == :hse
      assert notice.notice_type == :improvement
    end

    test "handles duplicate records during sync" do
      # Setup
      {:ok, agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive"
      })

      # Create existing case
      {:ok, _existing_case} = Enforcement.create_case(%{
        agency_code: :hse,
        regulator_id: "HSE999",
        offender_attrs: %{
          name: "Existing Company Ltd",
          postcode: "M5 5EE"
        },
        offence_action_date: ~D[2023-05-01],
        offence_fine: Decimal.new("2000.00")
      })

      # This will fail because SyncManager.sync_agency/2 doesn't exist yet
      result = SyncManager.sync_agency(:hse, :cases)
      
      # Should handle the duplicate gracefully
      assert :ok = result

      # Should still only have one case
      {:ok, cases} = Enforcement.list_cases(filter: [regulator_id: "HSE999"])
      assert length(cases) == 1
    end

    test "processes large batches efficiently" do
      # Setup
      {:ok, _agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive"
      })

      # For this test, we'll create a smaller batch since we're using mock data
      # The test is more about verifying the mechanism works than actual large data
      {duration_us, result} = :timer.tc(fn ->
        SyncManager.sync_agency(:hse, :cases)
      end)

      assert :ok = result

      # Verify records were created (mock returns 1 record)
      {:ok, cases} = Enforcement.list_cases()
      assert length(cases) == 1

      # Should complete quickly with mock data
      duration_seconds = duration_us / 1_000_000
      assert duration_seconds < 1
    end
  end

end