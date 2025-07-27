defmodule EhsEnforcement.Sync.SyncWorkerTest do
  use EhsEnforcement.DataCase, async: false  # async: false due to Oban testing

  alias EhsEnforcement.Sync.SyncWorker
  alias EhsEnforcement.Enforcement
  
  setup do
    # Enable test environment and mock scraping
    Application.put_env(:ehs_enforcement, :test_environment, true)
    Application.put_env(:ehs_enforcement, :mock_scraping, true)
    
    on_exit(fn ->
      Application.delete_env(:ehs_enforcement, :test_environment)
      Application.delete_env(:ehs_enforcement, :mock_scraping)
      Process.delete(:simulate_sync_error)
    end)
    
    :ok
  end

  describe "perform/1 for cases sync" do
    test "processes HSE cases sync job successfully" do
      # Setup agency
      {:ok, agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive"
      })

      # Create Oban job
      job = %{args: %{"agency" => "hse", "type" => "cases"}}

      # This will fail because SyncWorker.perform/1 doesn't exist yet
      assert :ok = SyncWorker.perform(job)

      # Verify cases were created (mock returns 1 case)
      {:ok, cases} = Enforcement.list_cases(load: [:offender, :agency])
      assert length(cases) == 1
    end

    test "handles errors in cases sync gracefully" do
      # Setup agency
      {:ok, _agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive"
      })

      # Set process dictionary to simulate error
      Process.put(:simulate_sync_error, true)

      job = %{args: %{"agency" => "hse", "type" => "cases"}}

      # This should now return the simulated error
      assert {:error, %RuntimeError{message: "Simulated sync error"}} = SyncWorker.perform(job)

      # No cases should be created due to error
      {:ok, cases} = Enforcement.list_cases()
      assert length(cases) == 0
    end

    test "validates agency exists before syncing cases" do
      job = %{args: %{"agency" => "nonexistent", "type" => "cases"}}

      # This will fail because SyncWorker.perform/1 doesn't exist yet
      result = SyncWorker.perform(job)
      assert {:error, _} = result
    end
  end

  describe "perform/1 for notices sync" do
    test "processes HSE notices sync job successfully" do
      # Setup agency
      {:ok, agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive"
      })

      # Create Oban job
      job = %{args: %{"agency" => "hse", "type" => "notices"}}

      # This will fail because SyncWorker.perform/1 doesn't exist yet
      assert :ok = SyncWorker.perform(job)

      # Verify notices were created (mock returns 1 notice)
      {:ok, notices} = Enforcement.list_notices(load: [:offender, :agency])
      assert length(notices) == 1
    end
  end

  describe "perform/1 error handling" do
    test "handles invalid job arguments" do
      # Missing agency
      job1 = %{args: %{"type" => "cases"}}
      
      # This will fail because SyncWorker.perform/1 doesn't exist yet
      assert {:error, :invalid_args} = SyncWorker.perform(job1)

      # Missing type
      job2 = %{args: %{"agency" => "hse"}}
      
      assert {:error, :invalid_args} = SyncWorker.perform(job2)
    end

    test "handles unsupported agency" do
      job = %{args: %{"agency" => "unsupported_agency", "type" => "cases"}}

      # This will fail because SyncWorker.perform/1 doesn't exist yet
      assert {:error, :unsupported_agency} = SyncWorker.perform(job)
    end
  end

  describe "job scheduling and retry logic" do
    test "can be scheduled via Oban" do
      # This will fail because SyncWorker.new/1 doesn't exist yet
      job_args = %{"agency" => "hse", "type" => "cases"}
      
      {:ok, job} = SyncWorker.new(job_args)

      assert job.worker == "EhsEnforcement.Sync.SyncWorker"
      assert job.args == job_args
    end
  end
end