defmodule EhsEnforcementWeb.DashboardLive do
  use EhsEnforcementWeb, :live_view

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Sync.SyncManager
  alias Phoenix.PubSub

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to real-time updates
    PubSub.subscribe(EhsEnforcement.PubSub, "sync:updates")
    PubSub.subscribe(EhsEnforcement.PubSub, "agency:updates")
    
    # Load initial data
    agencies = Enforcement.list_agencies!()
    recent_cases = load_recent_cases()
    stats = calculate_stats(agencies, recent_cases)
    
    {:ok,
     socket
     |> assign(:agencies, agencies)
     |> assign(:recent_cases, recent_cases)
     |> assign(:stats, stats)
     |> assign(:loading, false)
     |> assign(:sync_status, %{})
     |> assign(:filter_agency, nil)
     |> assign(:time_period, "week")}
  end

  @impl true
  def handle_event("sync_agency", %{"agency" => agency_code}, socket) do
    agency_code = String.to_existing_atom(agency_code)
    
    # Start sync process
    Task.start(fn ->
      SyncManager.sync_agency(agency_code)
    end)
    
    # Update UI to show sync in progress
    sync_status = Map.put(socket.assigns.sync_status, agency_code, %{status: "syncing", progress: 0})
    
    {:noreply, assign(socket, :sync_status, sync_status)}
  end

  @impl true
  def handle_event("filter_by_agency", %{"agency" => agency_id}, socket) do
    filter_agency = if agency_id == "", do: nil, else: agency_id
    recent_cases = load_recent_cases(filter_agency)
    
    {:noreply,
     socket
     |> assign(:filter_agency, filter_agency)
     |> assign(:recent_cases, recent_cases)}
  end

  @impl true
  def handle_event("change_time_period", %{"period" => period}, socket) do
    agencies = socket.assigns.agencies
    recent_cases = load_recent_cases(socket.assigns.filter_agency)
    stats = calculate_stats(agencies, recent_cases, period)
    
    {:noreply,
     socket
     |> assign(:time_period, period)
     |> assign(:stats, stats)}
  end

  @impl true
  def handle_event("export_data", %{"format" => format}, socket) do
    # In a real implementation, this would generate and download the file
    # For now, we'll just send a flash message
    {:noreply, put_flash(socket, :info, "Export to #{format} started")}
  end

  @impl true
  def handle_info({:sync_progress, agency_code, progress}, socket) do
    sync_status = Map.update(
      socket.assigns.sync_status,
      agency_code,
      %{status: "syncing", progress: progress},
      fn status -> %{status | progress: progress} end
    )
    
    {:noreply, assign(socket, :sync_status, sync_status)}
  end

  @impl true
  def handle_info({:sync_complete, agency_code}, socket) do
    # Reload data after sync
    agencies = Enforcement.list_agencies!()
    recent_cases = load_recent_cases(socket.assigns.filter_agency)
    stats = calculate_stats(agencies, recent_cases, socket.assigns.time_period)
    
    sync_status = Map.put(socket.assigns.sync_status, agency_code, %{status: "completed", progress: 100})
    
    {:noreply,
     socket
     |> assign(:agencies, agencies)
     |> assign(:recent_cases, recent_cases)
     |> assign(:stats, stats)
     |> assign(:sync_status, sync_status)}
  end

  @impl true
  def handle_info({:case_created, _case}, socket) do
    # Reload recent cases when a new case is created
    recent_cases = load_recent_cases(socket.assigns.filter_agency)
    stats = calculate_stats(socket.assigns.agencies, recent_cases, socket.assigns.time_period)
    
    {:noreply,
     socket
     |> assign(:recent_cases, recent_cases)
     |> assign(:stats, stats)}
  end

  defp load_recent_cases(filter_agency \\ nil) do
    filter = if filter_agency, do: [agency_id: filter_agency], else: []
    
    Enforcement.list_cases!(
      filter: filter,
      sort: [offence_action_date: :desc],
      limit: 10,
      load: [:offender, :agency]
    )
  end

  defp calculate_stats(agencies, recent_cases, period \\ "week") do
    total_cases = length(recent_cases)
    
    # Calculate total fines from recent cases
    total_fines = recent_cases
      |> Enum.map(& &1.offence_fine || Decimal.new(0))
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
    
    # Get agency-specific stats
    agency_stats = Enum.map(agencies, fn agency ->
      agency_cases = Enum.filter(recent_cases, & &1.agency_id == agency.id)
      case_count = length(agency_cases)
      
      %{
        agency_id: agency.id,
        agency_code: agency.code,
        agency_name: agency.name,
        case_count: case_count,
        percentage: if(total_cases > 0, do: Float.round(case_count / total_cases * 100, 1), else: 0)
      }
    end)
    
    %{
      total_cases: total_cases,
      total_fines: total_fines,
      active_agencies: Enum.count(agencies, & &1.active),
      agency_stats: agency_stats,
      period: period
    }
  end
end