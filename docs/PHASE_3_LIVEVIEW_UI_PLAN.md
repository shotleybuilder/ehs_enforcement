# Phase 3: LiveView UI Implementation Plan

**Status**: In Progress - Phase 3.1 Complete ✅
**Last Updated**: 2025-07-25
**Estimated Duration**: 2-3 weeks

## Executive Summary

Implement a comprehensive Phoenix LiveView interface for the EHS Enforcement application using the Ash framework as the core data layer. This phase includes Ash resource design, database setup through Ash migrations, data migration from Airtable, and interactive user interfaces powered by Ash queries and actions. PostgreSQL becomes the primary data store via AshPostgres, with Airtable being used only for one-time historical data import, after which it can be retired.

## Phase 3 Components

### 3.1 Ash Framework Setup and Resource Design ✅ COMPLETE

**Status**: All Ash resources implemented and tested (23 tests passing)

#### Architecture Implemented

**Domain Structure**: Two-domain architecture separating core enforcement logic from sync operations:
- `EhsEnforcement.Enforcement` - Core domain with Agency, Offender, Case, Notice, Breach resources  
- `EhsEnforcement.Sync` - Sync domain for data import/export operations
- `EhsEnforcement.Registry` - Centralized resource registry

#### Key Architectural Decisions

**Resource Design Patterns**:
- **Agency**: Atom-based codes (:hse, :onr, :orr, :ea) with constraint validation
- **Offender**: Automatic name normalization with deduplication logic ("Company Ltd" → "company limited")
- **Case**: Dual creation modes - direct IDs or lookup-based with agency_code + offender_attrs
- **Statistics**: Non-atomic statistics tracking in Offender (total_cases, total_notices, total_fines)

**Relationship Management**:
- Custom change functions for complex relationship creation (Case → Agency + Offender)
- OffenderMatcher service for find-or-create with fuzzy matching
- Error handling that converts `{:ok, nil}` to `{:error, :not_found}` for proper flow control

**Data Layer Features**:
- AshPostgres with automatic UUID primary keys
- Identity constraints with conditional WHERE clauses
- Calculations for derived data (total_penalty, enforcement_count)
- Rich filtering and search capabilities

#### Critical Implementation Notes

**OffenderMatcher Pattern**: Handles duplicate detection by normalizing company names and postcodes, with fallback to fuzzy search before creating new records.

**Case Creation Flexibility**: Supports both direct foreign key assignment and intelligent lookup-based creation via agency codes and offender attributes.

**Statistics Management**: Uses non-atomic updates with explicit transaction handling for offender statistics. This was chosen over Ash atomic operations due to argument passing complexity.

**Error Handling**: Domain functions return consistent `{:ok, result}` or `{:error, reason}` patterns, with proper Ash error translation in tests.

#### Migration Strategy Implemented

Generated Ash migrations create normalized PostgreSQL schema with proper indexes, constraints, and relationships. All migrations successfully applied with no manual SQL required.

#### Testing Approach

Comprehensive test coverage using TDD principles:
- Resource validation and constraint testing
- Complex relationship creation scenarios  
- Statistics update workflows
- Search and filtering capabilities
- Error condition handling

**Migration Path**: Direct transition from flat Airtable structure to normalized Ash resources ready for LiveView integration.

### 3.2 Data Import and Sync Architecture with Ash (Week 1, Days 3-4)

#### Ash-based Sync Architecture
```elixir
# lib/ehs_enforcement/sync/sync_manager.ex
defmodule EhsEnforcement.Sync.SyncManager do
  use GenServer
  alias EhsEnforcement.Enforcement
  
  @doc """
  Sync strategy that will evolve:
  Phase 3: Import from Airtable (one-time migration)
  Phase 4+: Direct scraping to PostgreSQL
  """
  
  # Import historical data from Airtable using Ash
  def import_from_airtable do
    # Fetch from Airtable
    airtable_records = fetch_airtable_data()
    
    # Use Ash bulk actions for efficient import
    Ash.bulk_create(
      airtable_records,
      EhsEnforcement.Enforcement.Case,
      :import_from_airtable,
      return_errors?: true,
      batch_size: 100
    )
  end
  
  # Direct agency sync using Ash actions
  def sync_agency(agency_code, sync_type) do
    # Get agency using Ash
    {:ok, agency} = Enforcement.get_agency_by_code(agency_code)
    
    # Fetch data from agency website
    scraped_data = scrape_agency_data(agency, sync_type)
    
    # Use Ash to create/update records
    Enum.each(scraped_data, fn data ->
      case sync_type do
        :cases -> 
          Enforcement.create_case(%{
            agency_code: agency_code,
            offender_attrs: extract_offender_attrs(data),
            # ... other attributes
          })
        :notices ->
          Enforcement.create_notice(%{
            agency_code: agency_code,
            offender_attrs: extract_offender_attrs(data),
            # ... other attributes
          })
      end
    end)
  end
end

# lib/ehs_enforcement/sync/offender_matcher.ex
defmodule EhsEnforcement.Sync.OffenderMatcher do
  alias EhsEnforcement.Enforcement
  
  @doc """
  Finds or creates an offender using Ash queries
  """
  def find_or_create_offender(attrs) do
    normalized_attrs = %{attrs | name: normalize_company_name(attrs.name)}
    
    # Use Ash to find existing offender
    case Enforcement.get_offender_by_name_and_postcode(
      normalized_attrs.name,
      normalized_attrs.postcode
    ) do
      {:ok, offender} -> 
        {:ok, offender}
      
      {:error, %Ash.Error.Query.NotFound{}} ->
        # Try fuzzy search using Ash
        case Enforcement.search_offenders(normalized_attrs.name) do
          {:ok, []} -> 
            # Create new offender using Ash
            Enforcement.create_offender(normalized_attrs)
          
          {:ok, similar_offenders} ->
            # Return best match or create new
            find_best_match(similar_offenders, normalized_attrs)
        end
    end
  end
  
  defp normalize_company_name(name) do
    name
    |> String.downcase()
    |> String.replace(~r/\s+(limited|ltd\.?)$/i, " limited")
    |> String.replace(~r/\s+(plc|p\.l\.c\.?)$/i, " plc")
    |> String.trim()
  end
end

# lib/ehs_enforcement/sync/sync_worker.ex
defmodule EhsEnforcement.Sync.SyncWorker do
  use Oban.Worker
  
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"agency" => agency, "type" => type}}) do
    # Direct scraping to PostgreSQL (no Airtable dependency)
    case type do
      "cases" -> 
        EhsEnforcement.Agencies.Hse.Cases.sync_to_postgres(agency)
      "notices" -> 
        EhsEnforcement.Agencies.Hse.Notices.sync_to_postgres(agency)
    end
  end
end

# lib/ehs_enforcement/sync/airtable_importer.ex
defmodule EhsEnforcement.Sync.AirtableImporter do
  @moduledoc """
  One-time import tool to migrate existing Airtable data using Ash.
  Can be removed after successful migration.
  """
  
  alias EhsEnforcement.Enforcement
  
  def import_all_data do
    # Paginate through Airtable records
    stream_airtable_records()
    |> Stream.chunk_every(100)
    |> Stream.each(&import_batch/1)
    |> Stream.run()
  end
  
  defp import_batch(records) do
    # Group records by type
    {cases, notices} = partition_records(records)
    
    # Import using Ash bulk operations
    with {:ok, _} <- import_cases_batch(cases),
         {:ok, _} <- import_notices_batch(notices) do
      :ok
    else
      {:error, error} ->
        Logger.error("Import batch failed: #{inspect(error)}")
    end
  end
  
  defp import_cases_batch(cases) do
    Ash.bulk_create(
      cases,
      EhsEnforcement.Enforcement.Case,
      :import_from_airtable,
      return_errors?: true,
      notify?: true,
      batch_size: 50
    )
  end
end
```

#### Migration Strategy:
1. **Phase 3.2**: One-time import from Airtable to PostgreSQL
2. **Phase 3.5+**: All new data goes directly to PostgreSQL via scrapers
3. **Post-Phase 3**: Airtable can be completely retired

#### Tasks:
- [ ] Create one-time Airtable import script
- [ ] Implement direct-to-PostgreSQL sync for scrapers
- [ ] Build data transformation layer (flat → normalized)
- [ ] Implement offender matching and deduplication
- [ ] Create offender statistics update logic
- [ ] Implement upsert logic to handle duplicates
- [ ] Add sync status tracking and error handling
- [ ] Create sync scheduling system
- [ ] Update HSE modules to support PostgreSQL writes

### 3.3 Configuration Management (Week 1, Day 5)

#### Runtime Configuration
```elixir
# config/runtime.exs additions
config :ehs_enforcement,
  # Airtable settings
  airtable: [
    api_key: System.get_env("AT_UK_E_API_KEY"),
    base_id: System.get_env("AIRTABLE_BASE_ID", "appq5OQW9bTHC1zO5"),
    sync_interval_minutes: String.to_integer(System.get_env("SYNC_INTERVAL", "60"))
  ],
  
  # Agency configurations
  agencies: [
    hse: [
      enabled: System.get_env("HSE_ENABLED", "true") == "true",
      base_url: "https://resources.hse.gov.uk",
      tables: %{
        cases: "tbl6NZm9bLU2ijivf",
        notices: "tbl6NZm9bLU2ijivf"
      }
    ]
  ],
  
  # Feature flags
  features: [
    auto_sync: System.get_env("AUTO_SYNC_ENABLED", "false") == "true",
    manual_sync: true,
    export_enabled: true
  ]
```

#### Tasks:
- [ ] Create comprehensive runtime configuration
- [ ] Add configuration validation on startup
- [ ] Implement feature flag system
- [ ] Create settings management module
- [ ] Add environment variable documentation

### 3.4 Error Handling and Logging (Week 2, Day 1)

#### Telemetry and Logging Setup
```elixir
# lib/ehs_enforcement/telemetry.ex
defmodule EhsEnforcement.Telemetry do
  def handle_event([:sync, :start], measurements, metadata, _config) do
    Logger.info("Starting sync for #{metadata.agency}")
  end
  
  def handle_event([:sync, :stop], measurements, metadata, _config) do
    duration = System.convert_time_unit(measurements.duration, :native, :millisecond)
    Logger.info("Sync completed for #{metadata.agency} in #{duration}ms")
  end
  
  def handle_event([:sync, :exception], _measurements, metadata, _config) do
    Logger.error("Sync failed for #{metadata.agency}: #{inspect(metadata.error)}")
  end
end
```

#### Tasks:
- [ ] Setup structured logging with metadata
- [ ] Implement telemetry events for key operations
- [ ] Create error boundary for LiveView
- [ ] Add Sentry integration for error tracking
- [ ] Implement retry logic with exponential backoff

### 3.5 Basic LiveView Dashboard with Ash (Week 2, Days 2-3)

#### Dashboard Components with Ash Integration
```elixir
# lib/ehs_enforcement_web/live/dashboard_live.ex
defmodule EhsEnforcementWeb.DashboardLive do
  use EhsEnforcementWeb, :live_view
  alias EhsEnforcement.Enforcement
  
  @impl true
  def mount(_params, _session, socket) do
    # Use Ash to load data
    agencies = Enforcement.list_agencies!()
    stats = load_statistics(agencies)
    
    {:ok, 
     socket
     |> assign(:agencies, agencies)
     |> assign(:stats, stats)
     |> assign(:recent_cases, load_recent_cases())
    }
  end
  
  defp load_recent_cases do
    Enforcement.list_cases!(
      sort: [offence_action_date: :desc],
      limit: 10,
      load: [:offender, :agency]
    )
  end
  
  defp load_statistics(agencies) do
    # Use Ash aggregates
    Enum.map(agencies, fn agency ->
      %{
        agency_id: agency.id,
        total_cases: Enforcement.count_cases!(filter: [agency_id: agency.id]),
        total_fines: Enforcement.sum_fines!(filter: [agency_id: agency.id]),
        last_sync: get_last_sync(agency)
      }
    end)
  end
end
```

#### Dashboard Features:
- Agency overview cards with sync status
- Recent enforcement activity timeline
- Statistics charts (cases by month, fines by agency)
- Quick actions (manual sync, export data)
- System health indicators

#### Tasks:
- [ ] Create main dashboard LiveView
- [ ] Build agency status cards component
- [ ] Implement activity timeline
- [ ] Add Chart.js integration for visualizations
- [ ] Create quick action buttons
- [ ] Add real-time updates via PubSub

### 3.6 Case Management Interface with Ash (Week 2, Days 4-5)

#### Case LiveView with Ash Queries
```elixir
# lib/ehs_enforcement_web/live/case_live/index.ex
defmodule EhsEnforcementWeb.CaseLive.Index do
  use EhsEnforcementWeb, :live_view
  alias EhsEnforcement.Enforcement
  
  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:cases, [])
     |> assign(:agencies, Enforcement.list_agencies!())
     |> assign(:filters, %{})
     |> assign(:page, 1)
     |> load_cases()
    }
  end
  
  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    {:noreply,
     socket
     |> assign(:filters, atomize_filters(filters))
     |> assign(:page, 1)
     |> load_cases()
    }
  end
  
  defp load_cases(socket) do
    # Build Ash query with filters
    query_opts = [
      filter: build_ash_filter(socket.assigns.filters),
      sort: [offence_action_date: :desc],
      page: [limit: 20, offset: (socket.assigns.page - 1) * 20],
      load: [:offender, :agency]
    ]
    
    cases = Enforcement.list_cases!(query_opts)
    assign(socket, :cases, cases)
  end
  
  defp build_ash_filter(filters) do
    Enum.reduce(filters, [], fn
      {:agency_id, id}, acc when id != "" -> 
        [agency_id: id | acc]
      {:date_from, date}, acc when date != "" -> 
        [offence_action_date: [greater_than_or_equal_to: date] | acc]
      {:date_to, date}, acc when date != "" -> 
        [offence_action_date: [less_than_or_equal_to: date] | acc]
      {:search, query}, acc when query != "" ->
        [or: [
          [offender: [name: [ilike: "%#{query}%"]]],
          [regulator_id: [ilike: "%#{query}%"]]
        ] | acc]
      _, acc -> acc
    end)
  end
end
```

#### Features:
- Paginated case listing with sorting
- Advanced filtering (agency, date range, fine amount)
- Search by offender name or case ID
- Case detail view with all fields
- Export to CSV functionality
- Manual case entry (for post-Airtable operations)
- Direct creation in PostgreSQL

#### Tasks:
- [ ] Create case index LiveView with pagination
- [ ] Implement filter component with live updates
- [ ] Build search functionality
- [ ] Create detailed case view
- [ ] Add CSV export feature
- [ ] Build manual case entry form
- [ ] Implement direct PostgreSQL operations

### 3.7 Notice Management Interface (Week 3, Days 1-2)

#### Notice LiveView Structure
```
lib/ehs_enforcement_web/live/notice_live/
├── index.ex          # Notice listing
├── show.ex           # Notice details
└── components/
    ├── notice_table.ex
    ├── notice_filters.ex
    └── notice_timeline.ex
```

#### Features:
- Notice listing with type categorization
- Timeline view of notices
- Geographic filtering by region
- Notice type statistics
- Compliance tracking

#### Tasks:
- [ ] Create notice index LiveView
- [ ] Build notice type filter
- [ ] Implement timeline visualization
- [ ] Add geographic filtering
- [ ] Create notice detail view
- [ ] Add compliance status tracking

### 3.8 Offender Management Interface (Week 3, Day 3)

#### Offender LiveView Structure
```
lib/ehs_enforcement_web/live/offender_live/
├── index.ex          # Offender listing
├── show.ex           # Offender enforcement history
└── components/
    ├── offender_table.ex
    ├── offender_card.ex
    └── enforcement_timeline.ex
```

#### Features:
- List of all offenders with enforcement statistics
- Detailed view showing all cases and notices for an offender
- Timeline visualization of enforcement history
- Repeat offender identification
- Industry and geographic analysis
- Export offender reports

#### Tasks:
- [ ] Create offender index LiveView
- [ ] Build enforcement history timeline
- [ ] Implement offender detail view
- [ ] Add statistics visualization
- [ ] Create repeat offender alerts
- [ ] Build export functionality

### 3.9 Search and Filter Capabilities with Ash (Week 3, Day 4)

#### Advanced Search with Ash Queries
```elixir
defmodule EhsEnforcement.Search do
  alias EhsEnforcement.Enforcement
  
  @doc """
  Search cases using Ash's powerful query capabilities
  """
  def search_cases(filters) do
    Enforcement.list_cases(
      filter: build_complex_filter(filters),
      sort: build_sort(filters[:sort_by]),
      load: [:offender, :agency, :breaches],
      page: [limit: filters[:limit] || 50]
    )
  end
  
  defp build_complex_filter(filters) do
    base_filter = []
    
    base_filter
    |> maybe_add_filter(:agency_id, filters[:agency_id])
    |> maybe_add_date_filter(:offence_action_date, filters[:from_date], :>=)
    |> maybe_add_date_filter(:offence_action_date, filters[:to_date], :<=)
    |> maybe_add_range_filter(:total_penalty, filters[:min_fine], filters[:max_fine])
    |> maybe_add_text_search(filters[:search])
  end
  
  defp maybe_add_text_search(filter, nil), do: filter
  defp maybe_add_text_search(filter, search_term) do
    # Ash supports complex OR conditions
    [or: [
      [offender: [name: [ilike: "%#{search_term}%"]]],
      [regulator_id: [ilike: "%#{search_term}%"]],
      [offence_breaches: [ilike: "%#{search_term}%"]]
    ] | filter]
  end
  
  @doc """
  Use Ash aggregates for analytics
  """
  def enforcement_statistics(filters \\ %{}) do
    %{
      total_cases: Enforcement.count_cases!(filter: filters),
      total_fines: Enforcement.aggregate_cases!(:sum, :offence_fine, filter: filters),
      avg_fine: Enforcement.aggregate_cases!(:avg, :offence_fine, filter: filters),
      top_offenders: get_top_offenders(filters)
    }
  end
end
```

#### Tasks:
- [ ] Implement full-text search using PostgreSQL
- [ ] Create composable query builder
- [ ] Add saved search functionality
- [ ] Implement search suggestions
- [ ] Create search analytics

### 3.10 Sync Status Monitoring (Week 3, Day 5)

#### Sync Monitoring Dashboard
```
lib/ehs_enforcement_web/live/sync_live/
├── index.ex              # Sync overview
├── logs.ex               # Detailed sync logs
└── components/
    ├── sync_progress.ex  # Real-time progress
    ├── sync_history.ex   # Historical data
    └── sync_controls.ex  # Manual sync triggers
```

#### Features:
- Real-time sync progress indicators
- Sync history with success/failure rates
- Manual sync triggers per agency
- Sync scheduling interface
- Error log viewer

#### Tasks:
- [ ] Create sync monitoring LiveView
- [ ] Implement real-time progress updates
- [ ] Build sync history table
- [ ] Add manual sync controls
- [ ] Create error detail viewer
- [ ] Implement sync scheduling UI

## Technical Implementation Details

### LiveView Patterns

#### 1. Live Components for Reusability
```elixir
defmodule EhsEnforcementWeb.Components.AgencyCard do
  use EhsEnforcementWeb, :live_component
  
  def render(assigns) do
    ~H"""
    <div class="agency-card">
      <h3><%= @agency.name %></h3>
      <div class="stats">
        <span>Cases: <%= @stats.total_cases %></span>
        <span>Last Sync: <%= format_date(@stats.last_sync) %></span>
      </div>
      <button phx-click="sync" phx-value-agency={@agency.code}>
        Sync Now
      </button>
    </div>
    """
  end
end
```

#### 2. PubSub for Real-time Updates
```elixir
# Subscribe to updates
def mount(_params, _session, socket) do
  Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "sync:updates")
  {:ok, socket}
end

# Handle updates
def handle_info({:sync_progress, agency, progress}, socket) do
  {:noreply, update(socket, :sync_status, &Map.put(&1, agency, progress))}
end
```

#### 3. Async Data Loading
```elixir
def mount(_params, _session, socket) do
  {:ok, socket |> assign(:cases, []) |> assign(:loading, true), temporary_assigns: [cases: []]}
end

def handle_params(params, _url, socket) do
  {:noreply, socket |> assign(:loading, true) |> load_cases(params)}
end

defp load_cases(socket, params) do
  send(self(), {:load_cases, params})
  socket
end

def handle_info({:load_cases, params}, socket) do
  cases = Enforcement.list_cases(params)
  {:noreply, socket |> assign(:cases, cases) |> assign(:loading, false)}
end
```

### Database Optimization with Ash

#### 1. Ash-Generated Indexes
```elixir
# Ash automatically creates indexes for:
# - Primary keys (UUID)
# - Foreign keys (agency_id, offender_id, case_id)
# - Unique constraints (identities)

# Additional custom indexes in Ash migrations:
defmodule EhsEnforcement.Repo.Migrations.AddSearchIndexes do
  use Ecto.Migration

  def up do
    # Full-text search index
    execute """
    CREATE INDEX cases_search_idx ON cases USING gin(
      to_tsvector('english', 
        COALESCE(regulator_id, '') || ' ' || 
        COALESCE(offence_breaches, '')
      )
    )
    """
    
    # Composite index for common queries
    create index(:cases, [:agency_id, :offence_action_date])
    create index(:offenders, [:name, :local_authority])
  end
end
```

#### 2. Ash Calculations for Statistics
```elixir
# Instead of materialized views, use Ash calculations
defmodule EhsEnforcement.Enforcement.Agency do
  # ... existing code ...
  
  calculations do
    calculate :total_cases, :integer do
      # Ash handles the aggregate query
      aggregate [:cases], :count
    end
    
    calculate :total_fines, :decimal do
      aggregate [:cases], :sum, field: :offence_fine
    end
    
    calculate :last_sync, :utc_datetime do
      aggregate [:cases], :max, field: :last_synced_at
    end
  end
end

# For complex statistics, use Ash aggregates
defmodule EhsEnforcement.Analytics do
  alias EhsEnforcement.Enforcement
  
  def agency_statistics do
    Enforcement.list_agencies!(
      load: [:total_cases, :total_fines, :last_sync]
    )
  end
  
  def offender_rankings do
    Enforcement.list_offenders!(
      sort: [total_fines: :desc],
      limit: 100,
      load: [:enforcement_count, :total_cases, :total_notices]
    )
  end
end
```

### UI/UX Considerations

#### 1. Responsive Design
- Mobile-first approach for field access
- Tablet optimization for data tables
- Desktop layouts for complex filtering

#### 2. Performance
- Implement virtual scrolling for large datasets
- Use LiveView streams for efficient updates
- Add loading states and skeleton screens
- Implement debounced search inputs

#### 3. Accessibility
- ARIA labels for all interactive elements
- Keyboard navigation support
- Screen reader friendly data tables
- High contrast mode support

## Testing Strategy

### 1. LiveView Tests
```elixir
test "displays agency cards on dashboard", %{conn: conn} do
  {:ok, view, html} = live(conn, "/")
  
  assert html =~ "Health and Safety Executive"
  assert has_element?(view, ".agency-card")
end

test "updates sync status in real-time", %{conn: conn} do
  {:ok, view, _html} = live(conn, "/")
  
  send(view.pid, {:sync_progress, "hse", 50})
  
  assert has_element?(view, "[data-sync-progress='50']")
end
```

### 2. Integration Tests
- Test full sync workflow from UI trigger
- Verify data persistence after sync
- Test error handling and recovery
- Validate export functionality
- Test offender deduplication logic
- Verify offender statistics updates

### 3. Performance Tests
- Load test with large datasets (10k+ records)
- Measure query performance
- Test concurrent user scenarios
- Monitor memory usage during sync

## Deployment Considerations

### 1. Database Migrations
```bash
# Run migrations on deployment
mix ecto.migrate

# Seed initial data
mix run priv/repo/seeds.exs
```

### 2. Asset Compilation
```bash
# Compile assets for production
mix assets.deploy
```

### 3. Environment Variables
```bash
# Required for Phase 3
DATABASE_URL=postgresql://user:pass@localhost/ehs_enforcement
AT_UK_E_API_KEY=your_airtable_key
SECRET_KEY_BASE=generated_secret
PHX_HOST=your-domain.com
```

## Success Criteria

1. **Functionality**
   - [ ] All HSE data viewable in UI
   - [ ] Manual sync works reliably
   - [ ] Search returns accurate results
   - [ ] Filters work correctly
   - [ ] Export produces valid CSV

2. **Performance**
   - [ ] Page load < 2 seconds
   - [ ] Search results < 1 second
   - [ ] Sync completes < 5 minutes
   - [ ] Supports 100+ concurrent users

3. **Reliability**
   - [ ] 99% uptime
   - [ ] Graceful error handling
   - [ ] Data consistency maintained
   - [ ] No data loss during sync

4. **Usability**
   - [ ] Intuitive navigation
   - [ ] Clear visual feedback
   - [ ] Mobile responsive
   - [ ] Accessible to screen readers

## Risk Mitigation

1. **Data Volume**: Implement pagination and lazy loading
2. **API Rate Limits**: Add request throttling and queuing
3. **Sync Failures**: Implement retry logic and partial sync recovery
4. **UI Performance**: Use LiveView streams and virtual scrolling
5. **Database Growth**: Plan for archiving old records

## Next Steps After Phase 3

1. **Phase 4 Preparation**
   - Research additional agency APIs
   - Plan multi-agency UI adjustments
   - Design agency-specific parsers

2. **User Feedback**
   - Deploy beta version
   - Gather user feedback
   - Prioritize improvements

3. **Performance Optimization**
   - Analyze slow queries
   - Implement caching layer
   - Optimize asset delivery

## Timeline Summary

**Week 1 (Days 1-5)**
- Days 1-2: Database setup
- Days 3-4: Sync implementation  
- Day 5: Configuration management

**Week 2 (Days 6-10)**
- Day 6: Error handling and logging
- Days 7-8: Dashboard implementation
- Days 9-10: Case management interface

**Week 3 (Days 11-15)**
- Days 11-12: Notice management interface
- Day 13: Offender management interface
- Day 14: Search and filters
- Day 15: Sync monitoring

**Buffer**: 2-3 days for testing, bug fixes, and deployment preparation

## Data Migration Path

### Current State (Phase 2)
- HSE scrapers write to Airtable
- Single flat table structure in Airtable
- No local data persistence

### Phase 3 Migration
1. **Week 1**: Set up PostgreSQL with normalized schema
2. **Week 1**: One-time import of historical Airtable data
3. **Week 2**: Update scrapers to write directly to PostgreSQL
4. **Week 3**: Verify all data flows work without Airtable
5. **Post-Phase 3**: Decommission Airtable integration

### End State (Post-Phase 3)
- All data stored in PostgreSQL
- Normalized relational structure
- No Airtable dependency
- Direct scraping to database
- Full data ownership and control

## Conclusion

Phase 3 establishes the foundation for a user-friendly, performant LiveView interface that brings together all the enforcement data collection capabilities built in Phases 1 and 2. The implementation focuses on reliability, usability, and extensibility to support future agency additions, while strategically migrating away from Airtable to a fully self-contained PostgreSQL solution.