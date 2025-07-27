ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(EhsEnforcement.Repo, :manual)

# Configure mock Airtable client for tests
Application.put_env(:ehs_enforcement, :airtable_client, EhsEnforcement.Test.AirtableMockClient)
