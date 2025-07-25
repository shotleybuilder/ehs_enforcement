defmodule EhsEnforcement.Test.ErrorAirtableClient do
  @moduledoc """
  Mock Airtable client that always returns errors for testing error handling.
  """
  
  @behaviour EhsEnforcement.Sync.AirtableClientBehaviour
  
  @impl true
  def get(_path, _params \\ %{}) do
    {:error, %{type: :timeout, message: "Simulated timeout error"}}
  end
end