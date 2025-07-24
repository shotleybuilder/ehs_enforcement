# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

**Framework**: Phoenix LiveView with Ash framework planned for future phases
**Database**: PostgreSQL (via Ecto) + Airtable integration
**HTTP Clients**: HTTPoison, Tesla, Req for external API calls
**UI**: Tailwind CSS + esbuild for assets

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