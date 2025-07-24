# Airtable Client Refactor Plan - HTTPoison to Req Migration

**Phase**: 2.1 Service Integration Sub-task  
**Status**: Planning  
**Timeline**: 2-3 days  
**Priority**: High  

## Overview

Refactor the Airtable client modules to use modern `Req` library instead of deprecated `HTTPoison`, while improving standalone functionality, error handling, and maintainability.

## Current Architecture Analysis

### Current Modules (HTTPoison-based):
```
lib/ehs_enforcement/integrations/airtable/
├── client.ex                    # HTTPoison.Base wrapper - NEEDS MAJOR REFACTOR
├── get.ex                      # GET operations using client.ex
├── post.ex                     # POST operations using Req (already migrated)
├── patch.ex                    # PATCH operations using Req (already migrated) 
├── at_post.ex                  # Legacy POST - REMOVE
├── at_patch.ex                 # Legacy PATCH using HTTPoison - REFACTOR
├── records.ex                  # Complex pagination logic using HTTPoison - REFACTOR
├── endpoint.ex                 # ✅ Simple endpoint URL provider
├── headers.ex                  # ✅ Headers with auth token
├── url.ex                      # ✅ URL building utilities
├── at_tables.ex               # ✅ Table ID management
├── at_bases.ex                # ✅ Base ID management  
├── at_bases_legl.ex           # ✅ Legacy base mapping
├── at_bases_tables.ex         # ✅ Combined base/table operations
├── uk_airtable.ex             # High-level API using records.ex - UPDATE
├── airtable_params.ex         # ✅ Parameter validation
├── at_fields.ex               # ✅ Field utilities
├── at_formulas.ex             # ✅ Formula building
└── at_views.ex                # ✅ View utilities
```

### Issues with Current Implementation:
1. **Mixed Libraries**: Some modules use HTTPoison, others use Req
2. **Inconsistent Error Handling**: Different error formats across modules
3. **Complex Client.ex**: HTTPoison.Base wrapper adds unnecessary complexity
4. **Legacy Code**: Multiple modules doing similar things (post.ex vs at_post.ex)
5. **Hard Dependencies**: Direct HTTPoison references throughout codebase

## Migration Strategy

### Phase 1: Core Client Refactor (Day 1)
**Goal**: Replace HTTPoison-based client.ex with clean Req-based implementation

#### 1.1 Create New Req-Based Client
- [ ] Create `lib/ehs_enforcement/integrations/airtable/req_client.ex`
- [ ] Implement standard HTTP methods (GET, POST, PATCH, DELETE)
- [ ] Add consistent error handling and response formatting
- [ ] Include rate limiting and retry logic
- [ ] Add request/response logging for debugging

#### 1.2 Update Core HTTP Modules
- [ ] **records.ex**: Migrate from HTTPoison to new req_client
- [ ] **get.ex**: Update to use req_client instead of old client.ex
- [ ] **at_patch.ex**: Migrate from HTTPoison to req_client (or remove if duplicate)

#### 1.3 Remove Legacy Code
- [ ] Remove old `client.ex` (HTTPoison.Base)
- [ ] Remove duplicate `at_post.ex` (keep req-based `post.ex`)
- [ ] Clean up any unused HTTPoison references

### Phase 2: High-Level API Updates (Day 2)
**Goal**: Update high-level modules to use new client consistently

#### 2.1 Update UK Airtable Module
- [ ] **uk_airtable.ex**: Update to use new client
- [ ] Standardize response handling across all methods
- [ ] Add better error messages and logging

#### 2.2 Standardize Response Format
- [ ] Define consistent response structure: `{:ok, data}` | `{:error, reason}`
- [ ] Update all modules to use standard format
- [ ] Add response validation and sanitization

#### 2.3 Add Configuration Management
- [ ] Centralize timeout, retry, and rate limit settings
- [ ] Make API key and base URL configurable via environment
- [ ] Add development vs production configuration options

### Phase 3: Error Handling & Resilience (Day 3)
**Goal**: Add robust error handling, rate limiting, and monitoring

#### 3.1 Enhanced Error Handling
- [ ] Define comprehensive error types and codes
- [ ] Add specific error handling for Airtable API limitations
- [ ] Implement graceful degradation for API failures
- [ ] Add error logging and metrics collection

#### 3.2 Rate Limiting & Retry Logic
- [ ] Implement Airtable rate limit compliance (5 requests/second)
- [ ] Add exponential backoff for failed requests
- [ ] Handle 429 (rate limit) responses appropriately
- [ ] Add circuit breaker pattern for service failures

#### 3.3 Testing & Validation
- [ ] Add unit tests for new req_client
- [ ] Add integration tests with Airtable sandbox
- [ ] Create mock client for testing without API calls
- [ ] Validate all existing functionality still works

## Detailed Implementation Plan

### New Req Client Architecture

```elixir
# lib/ehs_enforcement/integrations/airtable/req_client.ex
defmodule EhsEnforcement.Integrations.Airtable.ReqClient do
  @moduledoc """
  Modern Req-based Airtable API client with rate limiting and error handling
  """
  
  require Logger
  
  @base_url "https://api.airtable.com/v0"
  @rate_limit_per_second 5
  @timeout 30_000
  @retry_attempts 3
  
  # Standard interface methods
  def get(path, params \\ %{}, opts \\ [])
  def post(path, data, opts \\ [])  
  def patch(path, data, opts \\ [])
  def delete(path, opts \\ [])
  
  # Internal implementation
  defp make_request(method, path, data, opts)
  defp handle_response({:ok, response})
  defp handle_response({:error, error})
  defp should_retry?(error, attempt)
  defp rate_limit_delay()
end
```

### Response Standardization

```elixir
# Standardized response format
{:ok, %{
  records: [...],
  offset: "...",
  metadata: %{...}
}}

# Standardized error format  
{:error, %{
  type: :rate_limit | :not_found | :validation | :network | :timeout,
  code: "...",
  message: "...",
  details: %{...}
}}
```

### Configuration Structure

```elixir
# config/config.exs
config :ehs_enforcement, :airtable,
  api_key: {:system, "AIRTABLE_API_KEY"},
  base_url: "https://api.airtable.com/v0",
  timeout: 30_000,
  rate_limit: 5,
  retry_attempts: 3,
  retry_backoff: :exponential
```

### Migration Checklist

#### Pre-Migration
- [ ] Audit all current HTTPoison usage
- [ ] Identify all modules that need updates
- [ ] Create comprehensive test coverage for existing functionality
- [ ] Document current API behavior and edge cases

#### Migration Steps
- [ ] Implement new ReqClient with feature parity
- [ ] Update one module at a time, testing each change
- [ ] Run integration tests after each module update
- [ ] Monitor for any breaking changes or regressions

#### Post-Migration
- [ ] Remove all HTTPoison dependencies from mix.exs
- [ ] Update documentation to reflect new client usage
- [ ] Add monitoring and alerting for API health
- [ ] Performance testing and optimization

## Risk Assessment & Mitigation

### High Risk
- **Breaking Changes**: API behavior changes could break existing functionality
  - *Mitigation*: Comprehensive testing and gradual rollout
  
- **Rate Limiting**: New client might trigger rate limits
  - *Mitigation*: Conservative rate limiting with monitoring

### Medium Risk  
- **Performance Impact**: New client might be slower/faster
  - *Mitigation*: Performance benchmarking and optimization

- **Configuration Issues**: Environment-specific problems
  - *Mitigation*: Staging environment testing

### Low Risk
- **Dependency Issues**: Req library compatibility
  - *Mitigation*: Req is well-maintained and stable

## Success Criteria

### Functional Requirements
- [ ] All existing Airtable operations continue to work
- [ ] No data loss or corruption during migration
- [ ] Error handling is improved, not degraded
- [ ] API rate limits are respected

### Non-Functional Requirements  
- [ ] Response times within 10% of current performance
- [ ] Memory usage does not increase significantly
- [ ] Code is more maintainable and readable
- [ ] Comprehensive test coverage (>80%)

### Quality Gates
- [ ] All tests pass (unit + integration)
- [ ] No HTTPoison references remain in codebase
- [ ] Documentation is updated and accurate
- [ ] Code review approved by team

## Timeline & Milestones

### Day 1: Core Refactor
- Morning: Implement new ReqClient
- Afternoon: Update records.ex and get.ex
- End of day: Core HTTP operations working

### Day 2: Integration Updates  
- Morning: Update uk_airtable.ex and high-level APIs
- Afternoon: Remove legacy code and standardize responses
- End of day: All modules using new client

### Day 3: Polish & Testing
- Morning: Add comprehensive error handling
- Afternoon: Final testing and documentation
- End of day: Ready for production deployment

## Dependencies

### Required for Migration
- `req` library (already in mix.exs)
- Access to Airtable test environment
- Comprehensive test suite

### Nice to Have
- Airtable API sandbox for safe testing
- Performance monitoring tools
- Automated testing pipeline

## Deliverables

1. **New ReqClient Module**: Clean, well-documented Req-based client
2. **Updated Integration Modules**: All Airtable modules using new client
3. **Comprehensive Tests**: Unit and integration test coverage
4. **Updated Documentation**: API usage and configuration guide
5. **Migration Report**: Performance comparison and lessons learned

---

**Next Steps**: 
1. Review and approve this plan
2. Set up testing environment
3. Begin Phase 1 implementation
4. Regular progress check-ins during migration