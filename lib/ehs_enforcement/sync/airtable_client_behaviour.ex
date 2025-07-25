defmodule EhsEnforcement.Sync.AirtableClientBehaviour do
  @moduledoc """
  Behaviour for Airtable client implementations.
  Allows for easy mocking in tests.
  """
  
  @callback get(path :: String.t(), params :: map()) :: 
    {:ok, map()} | {:error, any()}
end