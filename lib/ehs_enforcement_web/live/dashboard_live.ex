defmodule EhsEnforcementWeb.DashboardLive do
  use EhsEnforcementWeb, :live_view

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Enforcement.RecentActivity
  alias EhsEnforcement.Sync.SyncManager
  alias Phoenix.PubSub

  @default_recent_activity_page_size 10

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to real-time updates
    PubSub.subscribe(EhsEnforcement.PubSub, "sync:updates")
    PubSub.subscribe(EhsEnforcement.PubSub, "agency:updates")
    
    # Load initial data
    agencies = Enforcement.list_agencies!()
    
    {:ok,
     socket
     |> assign(:agencies, agencies)
     |> assign(:recent_cases, [])
     |> assign(:total_recent_cases, 0)
     |> assign(:recent_activity_page, 1)
     |> assign(:recent_activity_page_size, @default_recent_activity_page_size)
     |> assign(:stats, %{})
     |> assign(:loading, false)
     |> assign(:sync_status, %{})
     |> assign(:filter_agency, nil)
     |> assign(:recent_activity_filter, :all)
     |> assign(:time_period, "week")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    recent_activity_page = String.to_integer(params["recent_activity_page"] || "1")
    
    # Load data first to get total count
    {recent_cases, total_recent_cases} = load_recent_cases_paginated(socket.assigns.filter_agency, recent_activity_page, socket.assigns.recent_activity_page_size)
    
    # Convert cases to recent activity format for the table
    recent_activity = format_cases_as_recent_activity(recent_cases)
    
    # Calculate stats
    stats = calculate_stats(socket.assigns.agencies, recent_cases, socket.assigns.time_period)
    
    # Ensure page is within valid range (recalculate if needed)
    max_page = calculate_max_page(total_recent_cases, socket.assigns.recent_activity_page_size)
    valid_page = max(1, min(recent_activity_page, max_page))
    
    # If page was out of range, reload with valid page
    final_data = if valid_page != recent_activity_page do
      load_recent_cases_paginated(socket.assigns.filter_agency, valid_page, socket.assigns.recent_activity_page_size)
    else
      {recent_cases, total_recent_cases}
    end
    
    {final_recent_cases, final_total_recent_cases} = final_data
    final_recent_activity = format_cases_as_recent_activity(final_recent_cases)
    
    {:noreply,
     socket
     |> assign(:recent_activity_page, valid_page)
     |> assign(:recent_cases, final_recent_cases)
     |> assign(:total_recent_cases, final_total_recent_cases)
     |> assign(:recent_activity, final_recent_activity)
     |> assign(:stats, stats)}
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
    {recent_cases, total_recent_cases} = load_recent_cases_paginated(filter_agency, 1, socket.assigns.recent_activity_page_size)
    recent_activity = format_cases_as_recent_activity(recent_cases)
    
    {:noreply,
     socket
     |> assign(:filter_agency, filter_agency)
     |> assign(:recent_cases, recent_cases)
     |> assign(:total_recent_cases, total_recent_cases)
     |> assign(:recent_activity, recent_activity)
     |> assign(:recent_activity_page, 1)
     |> push_patch(to: ~p"/dashboard")}
  end

  @impl true
  def handle_event("recent_activity_next_page", _params, socket) do
    current_page = socket.assigns.recent_activity_page
    max_page = calculate_max_page(socket.assigns.total_recent_cases, socket.assigns.recent_activity_page_size)
    
    if current_page < max_page do
      next_page = current_page + 1
      {:noreply, push_patch(socket, to: ~p"/dashboard?recent_activity_page=#{next_page}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("recent_activity_prev_page", _params, socket) do
    current_page = socket.assigns.recent_activity_page
    
    if current_page > 1 do
      prev_page = current_page - 1
      {:noreply, push_patch(socket, to: ~p"/dashboard?recent_activity_page=#{prev_page}")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change_time_period", %{"period" => period}, socket) do
    agencies = socket.assigns.agencies
    {recent_cases, total_recent_cases} = load_recent_cases_paginated(socket.assigns.filter_agency, socket.assigns.recent_activity_page, socket.assigns.recent_activity_page_size)
    recent_activity = format_cases_as_recent_activity(recent_cases)
    stats = calculate_stats(agencies, recent_cases, period)
    
    {:noreply,
     socket
     |> assign(:time_period, period)
     |> assign(:recent_cases, recent_cases)
     |> assign(:total_recent_cases, total_recent_cases)
     |> assign(:recent_activity, recent_activity)
     |> assign(:stats, stats)}
  end

  @impl true
  def handle_event("filter_recent_activity", %{"type" => type}, socket) do
    filter_type = String.to_existing_atom(type)
    
    # For now, we only support filtering cases since that's what we have data for
    # In the future, this could filter between cases and notices from different sources
    {recent_cases, total_recent_cases} = load_recent_cases_paginated(socket.assigns.filter_agency, 1, socket.assigns.recent_activity_page_size)
    recent_activity = format_cases_as_recent_activity(recent_cases)
    
    {:noreply,
     socket
     |> assign(:recent_activity_filter, filter_type)
     |> assign(:recent_activity, recent_activity)
     |> assign(:recent_cases, recent_cases)
     |> assign(:total_recent_cases, total_recent_cases)
     |> assign(:recent_activity_page, 1)}
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
    {recent_cases, total_recent_cases} = load_recent_cases_paginated(socket.assigns.filter_agency, socket.assigns.recent_activity_page, socket.assigns.recent_activity_page_size)
    recent_activity = format_cases_as_recent_activity(recent_cases)
    stats = calculate_stats(agencies, recent_cases, socket.assigns.time_period)
    
    sync_status = Map.put(socket.assigns.sync_status, agency_code, %{status: "completed", progress: 100})
    
    {:noreply,
     socket
     |> assign(:agencies, agencies)
     |> assign(:recent_cases, recent_cases)
     |> assign(:total_recent_cases, total_recent_cases)
     |> assign(:recent_activity, recent_activity)
     |> assign(:stats, stats)
     |> assign(:sync_status, sync_status)}
  end

  @impl true
  def handle_info({:sync_error, agency_code, error_message}, socket) do
    sync_status = Map.put(socket.assigns.sync_status, agency_code, %{status: "error", error: error_message})
    
    {:noreply, assign(socket, :sync_status, sync_status)}
  end

  @impl true
  def handle_info({:case_created, _case}, socket) do
    # Reload recent cases when a new case is created
    {recent_cases, total_recent_cases} = load_recent_cases_paginated(socket.assigns.filter_agency, socket.assigns.recent_activity_page, socket.assigns.recent_activity_page_size)
    recent_activity = format_cases_as_recent_activity(recent_cases)
    stats = calculate_stats(socket.assigns.agencies, recent_cases, socket.assigns.time_period)
    
    {:noreply,
     socket
     |> assign(:recent_cases, recent_cases)
     |> assign(:total_recent_cases, total_recent_cases)
     |> assign(:recent_activity, recent_activity)
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

  defp load_recent_cases_paginated(filter_agency \\ nil, page \\ 1, page_size \\ @default_recent_activity_page_size) do
    filter = if filter_agency, do: [agency_id: filter_agency], else: []
    offset = (page - 1) * page_size
    
    try do
      # Load cases
      cases_query_opts = [
        filter: filter,
        sort: [offence_action_date: :desc],
        load: [:offender, :agency]
      ]
      cases = Enforcement.list_cases!(cases_query_opts)
      
      # Load notices  
      notices_query_opts = [
        filter: filter,
        sort: [offence_action_date: :desc],
        load: [:offender, :agency]
      ]
      notices = Enforcement.list_notices!(notices_query_opts)
      
      # Combine and sort by date
      all_activity = (cases ++ notices)
      |> Enum.sort_by(& &1.offence_action_date, {:desc, Date})
      
      # Calculate total count
      total_count = length(all_activity)
      
      # Apply pagination
      paginated_activity = all_activity
      |> Enum.drop(offset)
      |> Enum.take(page_size)
      
      {paginated_activity, total_count}
    rescue
      error ->
        require Logger
        Logger.error("Failed to load paginated recent activity: #{inspect(error)}")
        {[], 0}
    end
  end

  defp calculate_max_page(total_items, page_size) when total_items <= 0, do: 1
  defp calculate_max_page(total_items, page_size) do
    ceil(total_items / page_size)
  end

  defp calculate_stats(agencies, recent_cases, period \\ "week") do
    total_cases = length(recent_cases)
    
    # Calculate total fines from recent cases (only cases have fines, not notices)
    total_fines = recent_cases
      |> Enum.filter(&match?(%EhsEnforcement.Enforcement.Case{}, &1))
      |> Enum.map(& Map.get(&1, :offence_fine, Decimal.new(0)) || Decimal.new(0))
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
      active_agencies: Enum.count(agencies, & &1.enabled),
      agency_stats: agency_stats,
      period: period
    }
  end

  defp format_cases_as_recent_activity(activity_records) do
    Enum.map(activity_records, fn record ->
      # Detect if this is a case or notice based on struct type
      is_case = match?(%EhsEnforcement.Enforcement.Case{}, record)
      
      %{
        id: record.id,
        type: record.offence_action_type || if(is_case, do: "Court Case", else: "Enforcement Notice"),
        date: record.offence_action_date,
        organization: record.offender.name,
        description: record.offence_breaches || if(is_case, do: "Court case proceeding", else: "Enforcement notice issued"),
        fine_amount: if(is_case, do: Map.get(record, :offence_fine, nil), else: nil),
        agency_link: record.url,
        is_case: is_case
      }
    end)
  end
end