# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## BUILD SUMMARIES

- **SAVE** Save build summaries to ~/Desktop/claude_build_summaries/[title of build summary].md

## ⚠️ CRITICAL ASH FRAMEWORK RULES

**🚫 NEVER USE STANDARD ECTO/PHOENIX PATTERNS - ALWAYS USE ASH PATTERNS**

### Database Operations
- **NEVER**: `Ecto.Changeset.cast/3`, `Repo.insert/1`, `Repo.update/1`, `Repo.get/2`
- **ALWAYS**: `Ash.create/2`, `Ash.update/2`, `Ash.read/2`, `Ash.get/2`, `Ash.destroy/2`

### Forms and Changesets
- **NEVER**: `Ecto.Changeset.change/2`, `Phoenix.HTML.Form` with Ecto changesets
- **ALWAYS**: `AshPhoenix.Form.for_create/3`, `AshPhoenix.Form.for_update/3`, `AshPhoenix.Form.validate/2`, `AshPhoenix.Form.submit/2`

### Data Queries
- **NEVER**: `from(u in User, where: u.role == :admin) |> Repo.all()`
- **ALWAYS**: `Ash.read(User, actor: current_user)` with Ash queries and filters

### Resource Actions
- **NEVER**: Define custom functions that bypass Ash actions
- **ALWAYS**: Use defined Ash actions like `:register_with_password`, `:update_role`, etc.

### Authentication Integration
- **NEVER**: Custom authentication logic bypassing Ash policies
- **ALWAYS**: Use `actor: current_user` parameter in all Ash calls for policy enforcement

### Error Handling
- **NEVER**: `{:error, %Ecto.Changeset{}}` pattern matching
- **ALWAYS**: `{:error, %Ash.Error{}}` and `AshPhoenix.Form` error handling

### Pre-Development Checklist
**Before writing ANY code that interacts with data:**
1. ✅ Check existing Ash resource definitions in `lib/sertantai/`
2. ✅ Identify available Ash actions (`:create`, `:read`, `:update`, `:destroy`, custom actions)
3. ✅ Use `AshPhoenix.Form` for all form handling
4. ✅ Use `Ash.*` functions for all database operations
5. ✅ Include `actor: current_user` in all calls for authorization
6. ✅ Test with Ash policies and authorization in mind

### Common Ash Patterns
```elixir
# Forms
form = AshPhoenix.Form.for_create(User, :register_with_password, forms: [auto?: false])
form = AshPhoenix.Form.for_update(user, :update, forms: [auto?: false])
form = AshPhoenix.Form.validate(form, params)
{:ok, user} = AshPhoenix.Form.submit(form, params: params)

# Database Operations
{:ok, users} = Ash.read(User, actor: current_user)
{:ok, user} = Ash.get(User, id, actor: current_user)
{:ok, user} = Ash.create(User, params, action: :register_with_password, actor: current_user)
{:ok, user} = Ash.update(user, params, action: :update, actor: current_user)
:ok = Ash.destroy(user, actor: current_user)
```

**⚠️ GOLDEN RULE**: After any code changes involving Ash resources, ALWAYS run:
1. `mix ash.codegen --check` (generate any needed migrations)
2. `mix ecto.migrate` (apply pending migrations)
3. THEN start the server with `mix phx.server`

**Never let the app run ahead of the database schema!**

**⚠️ ASH QUERY COMPILATION REQUIREMENTS:**
- **ALWAYS add `require Ash.Query` and `import Ash.Expr`** at the top of test files using Ash queries
- **Required for filter expressions**: `Ash.Query.filter(active == true)` won't compile without these imports
- **Enables query building**: Without these, variables like `active` in filters cause "undefined variable" errors
- **Add BEFORE any Ash.Query operations**: Place after other aliases but before describe blocks

**⚠️ MIGRATION SAFETY RULES:**
- **ALWAYS check existing schema** before creating migrations with `mix ecto.migrations`
- **NEVER assume table structure** - use `\d table_name` in psql or check existing migrations
- **VERIFY resource snapshots** in `priv/resource_snapshots/` before running `mix ash.codegen`
- **TEST migrations safely** by checking generated SQL in migration files before applying
- **REMOVE EXISTING TABLES** from generated migrations if they already exist in the database

## Development Commands

### Essential Commands
- `mix setup` - Install dependencies, setup database, and build assets
- `mix phx.server` - Start Phoenix server (http://localhost:4000)
- `iex -S mix phx.server` - Start server with interactive Elixir shell
- `mix test` - Run all tests
- `mix ecto.reset` - Drop, create, migrate, and seed database

### Asset Management
- `mix assets.build` - Build assets (Tailwind CSS + esbuild)
- `mix assets.deploy` - Build and minify assets for production

### Database Operations
- `mix ecto.create` - Create database
- `mix ecto.migrate` - Run database migrations
- `mix ecto.drop` - Drop database

## Architecture Overview

This is a Phoenix LiveView application for collecting and managing UK environmental, health, and safety enforcement data. The app is currently in Phase 2 of development, transitioning from legacy `Legl.*` modules to new `EhsEnforcement.*` structure.

### Core Components

**Legacy Structure (being refactored)**:
- `Legl.Countries.Uk.LeglEnforcement.*` - HSE enforcement processing modules
- `Legl.Services.Hse.*` - HSE website scraping clients
- `Legl.Services.Airtable.*` - Airtable API integration

**Target Structure**:
- `EhsEnforcement.Agencies.*` - Agency-specific data collection and processing
- `EhsEnforcement.Integrations.*` - External service integrations (Airtable, etc.)
- `EhsEnforcement.Enforcement.*` - Core enforcement data models (future Ash resources)

### Key Dependencies

- **Database**: PostgreSQL (via Ecto) + Airtable integration
- **HTTP Clients**: Tesla, Req for external API calls
- **Phoenix 1.7+** - Web framework
- **Ash 3.0+** - Data modeling and business logic framework
- **Ash Phoenix** - Phoenix integration for Ash
- **LiveView** - Real-time UI components
- **Ecto/PostgreSQL** - Database layer
- **Tailwind CSS** - Styling framework
- **ESBuild** - JavaScript bundling

### Data Flow

1. **HSE Scraping**: `ClientCases`/`ClientNotices` modules fetch data from HSE website
2. **Processing**: HSE modules parse and structure enforcement data
3. **Storage**: Data synced to Airtable (primary) with future PostgreSQL caching
4. **UI**: Phoenix LiveView interfaces for monitoring and management

### Current Development Phase

**Phase 2: Service Integration** - Module refactoring from `Legl.*` to `EhsEnforcement.*` namespace is in progress. See `docs/MODULE_REFACTORING.md` for detailed mapping.

### Configuration

- Airtable API credentials via `AT_UK_E_API_KEY` environment variable
- Database configuration in `config/` directory
- Agency-specific settings planned for `config/runtime.exs`

### Testing

- Test files follow same structure as `lib/` directory
- HSE enforcement logic has existing test coverage in `test/ehs_enforcement/countries/uk/legl_enforcement/`
- Use `mix test path/to/specific_test.exs` for single test files

**⚠️ CRITICAL TESTING RULES:**
- **NEVER create scripts in `/scripts` for testing** - Always use proper ExUnit tests in `/test` folder
- **ALWAYS use ExUnit framework** with `describe` blocks, proper `setup` callbacks, and `test` macros
- **FOLLOW Phoenix LiveView testing patterns** using `Phoenix.LiveViewTest` for LiveView components
- **USE proper test assertions** like `assert`, `refute`, `assert_receive`, etc.
- **CREATE integration tests** in `/test` folder that mirror real application usage
- **INCLUDE proper test setup and teardown** with database transactions

### ExUnit Testing Patterns
```elixir
defmodule MyAppWeb.MyLiveTest do
  use MyAppWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "LiveView functionality" do
    setup do
      # Setup test data using Ash patterns
      {:ok, user} = MyApp.Accounts.create_user(%{...})
      %{user: user}
    end

    test "displays data correctly", %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, "/path")
      assert html =~ "expected content"
      assert has_element?(view, "[data-testid='element']")
    end
  end
end
```

**MANUAL TESTING APPROACH (Secondary):**
1. **Use Tidewave MCP** to examine test results and outputs instead of running tests directly
2. **Access via**: /home/jason/mcp-proxy http://localhost:4000/tidewave/mcp
3. **Query test files** and examine expected vs actual behavior through MCP interface
4. **Validate functionality** by examining code paths and test assertions manually

**⚠️ PORT CONFLICT RULE**:
- **Port 4000 is reserved** for Tidewave MCP server integration
- **Always test Phoenix server on port 4001** using `PORT=4001 mix phx.server`
- **Never kill processes on port 4000** - this breaks MCP connectivity
