# Module Refactoring Plan

## Current Structure → New Structure

### HSE Enforcement Modules
```
Legl.Countries.Uk.LeglEnforcement.Hse → EhsEnforcement.Agencies.Hse.Common
Legl.Countries.Uk.LeglEnforcement.HseCases → EhsEnforcement.Agencies.Hse.Cases
Legl.Countries.Uk.LeglEnforcement.HseNotices → EhsEnforcement.Agencies.Hse.Notices
Legl.Countries.Uk.LeglEnforcement.HseBreaches → EhsEnforcement.Agencies.Hse.Breaches
```

### HSE Service Clients
```
Legl.Services.Hse.ClientCases → EhsEnforcement.Agencies.Hse.CaseScraper
Legl.Services.Hse.ClientNotices → EhsEnforcement.Agencies.Hse.NoticeScraper
```

### Airtable Services
```
Legl.Services.Airtable.* →  EhsEnforcement.Integrations.Airtable.*
```

### New Directory Structure
```
lib/ehs_enforcement/
├── agencies/
│   └── hse/
│       ├── common.ex (utility functions)
│       ├── cases.ex (case processing)
│       ├── notices.ex (notice processing) 
│       ├── breaches.ex (breach parsing)
│       ├── case_scraper.ex (HSE website scraping)
│       └── notice_scraper.ex (HSE website scraping)
├── integrations/
│   └── airtable/
│       ├── client.ex
│       ├── headers.ex
│       ├── endpoint.ex
│       └── ... (other airtable modules)
└── ... (existing Phoenix modules)
```

## Status
- [x] Created common.ex
- [ ] Move and refactor remaining HSE modules
- [ ] Move and refactor Airtable modules
- [ ] Update all alias and import statements
- [ ] Update all function calls
- [ ] Test compilation