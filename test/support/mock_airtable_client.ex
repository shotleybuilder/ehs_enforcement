defmodule EhsEnforcement.Test.MockAirtableClient do
  @moduledoc """
  Mock Airtable client for testing.
  Returns predefined responses without making real API calls.
  """
  
  @behaviour EhsEnforcement.Sync.AirtableClientBehaviour
  
  @impl true
  def get(path, params \\ %{}) do
    case {path, params} do
      {"/appq5OQW9bTHC1zO5/tbl6NZm9bLU2ijivf", %{}} ->
        # First page
        {:ok, %{
          "records" => mock_records(),
          "offset" => "page2"
        }}
        
      {"/appq5OQW9bTHC1zO5/tbl6NZm9bLU2ijivf", %{offset: "page2"}} ->
        # Second page (no more pages)
        {:ok, %{
          "records" => []
        }}
        
      _ ->
        {:error, %{type: :not_found, message: "Mock not found"}}
    end
  end
  
  defp mock_records do
    [
      %{
        "id" => "rec001",
        "fields" => %{
          "regulator_id" => "HSE001",
          "offender_name" => "Test Company Ltd",
          "offender_postcode" => "M1 1AA",
          "offence_action_date" => "2023-01-15",
          "offence_fine" => "5000.00",
          "offence_breaches" => "Safety regulation breach",
          "agency_code" => "hse"
        }
      },
      %{
        "id" => "rec002",
        "fields" => %{
          "regulator_id" => "HSE002",
          "offender_name" => "Another Corp Ltd",
          "offender_postcode" => "M2 2BB",
          "offence_action_date" => "2023-02-20",
          "offence_fine" => "10000.00",
          "offence_breaches" => "Health regulation breach",
          "agency_code" => "hse"
        }
      }
    ]
  end
end