# EHS Enforcement

UK enforcement agency activity data collection and publishing system for Airtable integration.

## Quick Start

### Database Setup (Required)

**First time setup:** See [Database Setup Guide](./README_DATABASE.md) for PostgreSQL configuration.

**Quick start after setup:**
```bash
ehs-dev       # Start server
ehs-dev iex   # Start in interactive mode
```

### Manual Start

To start your Phoenix server:

  * Start PostgreSQL: `docker-compose up -d postgres`
  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Testing HSE Scrapers

Once database is running, test in iex:

```elixir
# Test HSE Notices
EhsEnforcement.Agencies.Hse.Notices.api_get_hse_notices([pages: "1"])

# Test HSE Cases
EhsEnforcement.Agencies.Hse.Cases.api_get_hse_cases([pages: "1"])
```

## Documentation

- [Implementation Plan](./docs/IMPLEMENTATION_PLAN.md)
- [Airtable Client Refactor](./docs/AIRTABLE_CLIENT_REFACTOR.md)
- [Database Setup](./README_DATABASE.md)

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
