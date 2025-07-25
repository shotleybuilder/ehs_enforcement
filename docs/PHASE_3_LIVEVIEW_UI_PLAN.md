# Phase 3: LiveView UI Implementation Plan

**Status**: Ready to Start
**Last Updated**: 2025-07-25
**Estimated Duration**: 2-3 weeks

## Executive Summary

Implement a comprehensive Phoenix LiveView interface for the EHS Enforcement application, including database setup, data migration from Airtable, configuration management, and interactive user interfaces for managing enforcement data. This phase establishes PostgreSQL as the primary data store, with Airtable being used only for one-time historical data import, after which it can be retired.

## Phase 3 Components

### 3.1 Database Setup and Data Layer (Week 1, Days 1-2)

#### PostgreSQL Schema Design
```sql
-- Agencies table
CREATE TABLE agencies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(10) UNIQUE NOT NULL, -- 'hse', 'onr', 'orr', 'ea'
  name VARCHAR(255) NOT NULL,
  base_url VARCHAR(255),
  active BOOLEAN DEFAULT true,
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Offenders table (companies/individuals subject to enforcement)
CREATE TABLE offenders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(500) NOT NULL,
  local_authority VARCHAR(255),
  postcode VARCHAR(20),
  main_activity VARCHAR(500),
  business_type VARCHAR(100), -- 'Limited Company', 'Individual', etc.
  industry VARCHAR(255),
  first_seen_date DATE,
  last_seen_date DATE,
  total_cases INTEGER DEFAULT 0,
  total_notices INTEGER DEFAULT 0,
  total_fines DECIMAL(12,2) DEFAULT 0,
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Cases table (local cache of Airtable data)
CREATE TABLE cases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id UUID REFERENCES agencies(id),
  offender_id UUID REFERENCES offenders(id),
  airtable_id VARCHAR(255) UNIQUE,
  regulator_id VARCHAR(100),
  offence_result VARCHAR(255),
  offence_fine DECIMAL(10,2),
  offence_costs DECIMAL(10,2),
  offence_action_date DATE,
  offence_hearing_date DATE,
  offence_breaches TEXT,
  offence_breaches_clean TEXT,
  regulator_function VARCHAR(255),
  regulator_url VARCHAR(500),
  related_cases TEXT, -- comma-separated list
  last_synced_at TIMESTAMP,
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Notices table
CREATE TABLE notices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id UUID REFERENCES agencies(id),
  offender_id UUID REFERENCES offenders(id),
  airtable_id VARCHAR(255) UNIQUE,
  regulator_id VARCHAR(100),
  regulator_ref_number VARCHAR(100),
  notice_type VARCHAR(100),
  notice_date DATE,
  operative_date DATE,
  compliance_date DATE,
  notice_body TEXT,
  last_synced_at TIMESTAMP,
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Breaches table (normalized from cases)
CREATE TABLE breaches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID REFERENCES cases(id),
  breach_description TEXT,
  legislation_reference VARCHAR(255),
  legislation_type VARCHAR(50), -- 'Act', 'Regulation', 'ACOP'
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Sync logs table
CREATE TABLE sync_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id UUID REFERENCES agencies(id),
  sync_type VARCHAR(50), -- 'cases', 'notices'
  status VARCHAR(50), -- 'started', 'completed', 'failed'
  records_synced INTEGER DEFAULT 0,
  error_message TEXT,
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_offenders_name ON offenders(name);
CREATE INDEX idx_offenders_local_authority ON offenders(local_authority);
CREATE INDEX idx_cases_agency_id ON cases(agency_id);
CREATE INDEX idx_cases_offender_id ON cases(offender_id);
CREATE INDEX idx_cases_airtable_id ON cases(airtable_id);
CREATE INDEX idx_notices_agency_id ON notices(agency_id);
CREATE INDEX idx_notices_offender_id ON notices(offender_id);
CREATE INDEX idx_notices_airtable_id ON notices(airtable_id);
CREATE INDEX idx_breaches_case_id ON breaches(case_id);
CREATE INDEX idx_sync_logs_agency_id ON sync_logs(agency_id);

-- Unique constraint to prevent duplicate offenders
CREATE UNIQUE INDEX idx_offenders_name_postcode ON offenders(LOWER(name), COALESCE(postcode, ''));
```

#### Schema Design Benefits:

1. **Normalized Offender Data**
   - Single source of truth for each company/individual
   - Track enforcement history across multiple cases and notices
   - Identify repeat offenders easily
   - Maintain consistent company information

2. **Deduplication Strategy**
   - Match offenders by normalized name + postcode
   - Handle variations in company names (Ltd vs Limited)
   - Update offender statistics on each sync
   - Link historical enforcement actions

3. **Enhanced Analytics**
   - Total fines per offender
   - Enforcement timeline per company
   - Industry-based analysis
   - Geographic distribution of offenders

#### Tasks:
- [ ] Create Ecto migrations for all tables
- [ ] Define Ecto schemas in `lib/ehs_enforcement/enforcement/`
- [ ] Create database seeds with initial agency data
- [ ] Implement Ecto changesets with validations
- [ ] Add database indexes for performance
- [ ] Implement offender matching/deduplication logic

### 3.2 Data Import and Sync Architecture (Week 1, Days 3-4)

#### Flexible Sync Architecture (Airtable → PostgreSQL → Direct Scraping)
```elixir
# lib/ehs_enforcement/sync/sync_manager.ex
defmodule EhsEnforcement.Sync.SyncManager do
  use GenServer
  
  @doc """
  Sync strategy that will evolve:
  Phase 3: Import from Airtable (one-time migration)
  Phase 4+: Direct scraping to PostgreSQL
  """
  
  # Import historical data from Airtable (one-time operation)
  def import_from_airtable do
    # One-time bulk import of existing Airtable data
    # Transform flat Airtable structure to normalized PostgreSQL
    # After import, Airtable can be retired
  end
  
  # Direct agency sync (future primary method)
  def sync_agency(agency_code, sync_type) do
    # Fetch directly from agency website (HSE, ONR, etc.)
    # Transform scraped data
    # Find or create offenders
    # Create cases/notices in PostgreSQL
    # Update offender statistics
    # Log sync results
  end
end

# lib/ehs_enforcement/sync/offender_matcher.ex
defmodule EhsEnforcement.Sync.OffenderMatcher do
  @doc """
  Finds or creates an offender based on name and location
  """
  def find_or_create_offender(attrs) do
    normalized_name = normalize_company_name(attrs.name)
    
    # Try exact match first
    offender = Repo.get_by(Offender, 
      name: normalized_name,
      postcode: attrs.postcode
    )
    
    # If no exact match, try fuzzy matching
    offender = offender || find_similar_offender(attrs)
    
    # Create new if no match found
    offender || create_offender(attrs)
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
  One-time import tool to migrate existing Airtable data.
  Can be removed after successful migration.
  """
  
  def import_all_data do
    # Paginate through Airtable records
    # Transform single table to normalized structure
    # Create offenders, cases, notices in PostgreSQL
    # Mark import as complete
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

### 3.5 Basic LiveView Dashboard (Week 2, Days 2-3)

#### Dashboard Components
```
lib/ehs_enforcement_web/live/
├── dashboard_live.ex           # Main dashboard
├── components/
│   ├── agency_card.ex         # Agency status card
│   ├── sync_status.ex         # Sync status indicator
│   ├── recent_activity.ex     # Recent cases/notices
│   └── statistics_chart.ex    # Data visualization
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

### 3.6 Case Management Interface (Week 2, Days 4-5)

#### Case LiveView Structure
```
lib/ehs_enforcement_web/live/case_live/
├── index.ex          # Case listing with filters
├── show.ex           # Case details view
├── new.ex            # Manual case entry (post-Airtable)
└── components/
    ├── case_table.ex
    ├── case_filters.ex
    └── case_card.ex
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

### 3.9 Search and Filter Capabilities (Week 3, Day 4)

#### Advanced Search Implementation
```elixir
defmodule EhsEnforcement.Search do
  import Ecto.Query
  
  def search_cases(query, filters) do
    Case
    |> filter_by_agency(filters[:agency])
    |> filter_by_date_range(filters[:from_date], filters[:to_date])
    |> filter_by_amount_range(filters[:min_fine], filters[:max_fine])
    |> search_by_text(filters[:search])
    |> order_by(^filters[:sort_by])
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

### Database Optimization

#### 1. Indexes for Common Queries
```sql
-- Text search
CREATE INDEX idx_cases_offender_name_gin ON cases USING gin(to_tsvector('english', offender_name));

-- Date range queries
CREATE INDEX idx_cases_action_date ON cases(offence_action_date);

-- Composite indexes for filtering
CREATE INDEX idx_cases_agency_date ON cases(agency_id, offence_action_date DESC);
```

#### 2. Materialized Views for Statistics
```sql
CREATE MATERIALIZED VIEW agency_statistics AS
SELECT 
  a.id as agency_id,
  COUNT(DISTINCT c.id) as total_cases,
  COUNT(DISTINCT n.id) as total_notices,
  SUM(c.offence_fine) as total_fines,
  MAX(c.last_synced_at) as last_case_sync,
  MAX(n.last_synced_at) as last_notice_sync
FROM agencies a
LEFT JOIN cases c ON c.agency_id = a.id
LEFT JOIN notices n ON n.agency_id = a.id
GROUP BY a.id;

CREATE MATERIALIZED VIEW offender_statistics AS
SELECT 
  o.id as offender_id,
  o.name,
  o.local_authority,
  COUNT(DISTINCT c.id) as case_count,
  COUNT(DISTINCT n.id) as notice_count,
  SUM(c.offence_fine + c.offence_costs) as total_penalties,
  MIN(LEAST(c.offence_action_date, n.notice_date)) as first_enforcement_date,
  MAX(GREATEST(c.offence_action_date, n.notice_date)) as last_enforcement_date
FROM offenders o
LEFT JOIN cases c ON c.offender_id = o.id
LEFT JOIN notices n ON n.offender_id = o.id
GROUP BY o.id, o.name, o.local_authority;

-- Refresh periodically
REFRESH MATERIALIZED VIEW CONCURRENTLY agency_statistics;
REFRESH MATERIALIZED VIEW CONCURRENTLY offender_statistics;
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