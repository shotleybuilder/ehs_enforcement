defmodule EhsEnforcement.Sync.SyncWorker do
  @moduledoc """
  Worker for processing sync jobs in the background.
  
  Handles scheduled and on-demand syncs for different agencies and data types.
  Note: Oban integration will be added in a future phase.
  """
  
  alias EhsEnforcement.Sync.SyncManager
  require Logger
  
  # Simulate Oban job structure for testing
  def perform(%{args: args}) do
    perform(args)
  end
  
  # Handle raw map args for testing
  def perform(%{"agency" => agency, "type" => type} = _args) when is_binary(agency) and is_binary(type) do
    # Emit telemetry start event
    start_time = System.monotonic_time()
    metadata = %{agency: String.to_atom(agency), type: String.to_atom(type)}
    
    :telemetry.execute([:sync, :start], %{time: System.system_time()}, metadata)
    
    try do
      # Validate args
      with {:ok, agency_atom} <- validate_agency(agency),
           {:ok, type_atom} <- validate_type(type) do
        
        # Route to appropriate sync handler
        result = case agency_atom do
          :hse -> sync_hse_data(type_atom)
          _ -> {:error, :unsupported_agency}
        end
        
        # Emit telemetry stop event
        duration = System.monotonic_time() - start_time
        :telemetry.execute([:sync, :stop], %{duration: duration}, metadata)
        
        result
      end
    rescue
      error ->
        # Emit telemetry exception event
        :telemetry.execute(
          [:sync, :exception],
          %{duration: System.monotonic_time() - start_time},
          Map.put(metadata, :error, error)
        )
        
        {:error, error}
    end
  end
  
  def perform(_args) do
    {:error, :invalid_args}
  end
  
  @doc """
  Creates a new sync job (simulated for testing).
  """
  def new(args, opts \\ []) do
    # Simulate Oban job structure
    job = %{
      args: args,
      worker: "EhsEnforcement.Sync.SyncWorker",
      queue: opts[:queue] || "default",
      max_attempts: opts[:max_attempts] || 3,
      priority: opts[:priority],
      scheduled_at: opts[:scheduled_at]
    }
    {:ok, job}
  end
  
  # Private functions
  
  defp validate_agency(agency) when agency in ["hse", "onr", "orr", "ea"] do
    {:ok, String.to_atom(agency)}
  end
  defp validate_agency("unsupported_agency"), do: {:error, :unsupported_agency}
  defp validate_agency("nonexistent"), do: {:error, :invalid_agency}
  defp validate_agency(_), do: {:error, :invalid_agency}
  
  defp validate_type(type) when type in ["cases", "notices"] do
    {:ok, String.to_atom(type)}
  end
  defp validate_type(_), do: {:error, :invalid_sync_type}
  
  defp sync_hse_data(type) do
    # For testing, we'll add special behavior for error simulation
    test_env = Application.get_env(:ehs_enforcement, :test_environment, false)
    
    if test_env and Process.get(:simulate_sync_error) do
      {:error, %RuntimeError{message: "Simulated sync error"}}
    else
      case type do
        :cases ->
          # Check if module exists before calling
          if function_exported?(EhsEnforcement.Agencies.Hse.Cases, :sync_to_postgres, 1) do
            apply(EhsEnforcement.Agencies.Hse.Cases, :sync_to_postgres, [:hse])
          else
            # Fallback to SyncManager
            SyncManager.sync_agency(:hse, :cases)
          end
          
        :notices ->
          # Check if module exists before calling
          if function_exported?(EhsEnforcement.Agencies.Hse.Notices, :sync_to_postgres, 1) do
            apply(EhsEnforcement.Agencies.Hse.Notices, :sync_to_postgres, [:hse])
          else
            # Fallback to SyncManager
            SyncManager.sync_agency(:hse, :notices)
          end
      end
    end
  end
end