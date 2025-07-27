defmodule EhsEnforcement.Test.AirtableMockClient do
  @moduledoc """
  Mock Airtable client for testing that provides predictable responses
  without making real HTTP requests.
  """

  @behaviour EhsEnforcement.Sync.AirtableClientBehaviour

  @doc """
  Mock GET request that returns test data based on parameters.
  """
  def get(path, params \\ %{}) do
    case determine_response_type(path, params) do
      :success_batch ->
        {:ok, %{
          "records" => generate_test_records(100),
          "offset" => "next_batch_offset"
        }}
      
      :success_final_batch ->
        {:ok, %{
          "records" => generate_test_records(50)
          # No offset = last page
        }}
      
      
      :success_mixed_batch ->
        {:ok, %{
          "records" => [
            %{
              "id" => "rec_case1",
              "fields" => %{
                "regulator_id" => "MIXED001",
                "offender_name" => "Mixed Case Company Ltd",
                "agency_code" => "hse",
                "offence_action_type" => "Court Case"
              }
            }
          ]
        }}
      
      :success_first_large_batch ->
        {:ok, %{
          "records" => generate_mixed_records(250), # 125 cases + 125 notices
          "offset" => "second_batch"
        }}
      
      :success_final_large_batch ->
        {:ok, %{
          "records" => generate_mixed_records(250) # Another 125 cases + 125 notices
        }}
      
      :success_large_performance_batch ->
        {:ok, %{"records" => generate_mixed_records(400)}} # 200 cases + 200 notices
      
      :success_first_then_fail ->
        # Return one record with offset to trigger second call
        {:ok, %{
          "records" => [
            %{
              "id" => "rec_success_001",
              "fields" => %{
                "regulator_id" => "SUCCESS001",
                "offender_name" => "Success Company Ltd",
                "agency_code" => "hse",
                "offence_action_type" => "Court Case"
              }
            }
          ],
          "offset" => "will_fail_next"
        }}
      
      :timeout ->
        {:error, %{reason: :timeout}}
      
      :malformed_json ->
        {:error, %Jason.DecodeError{data: "invalid json"}}
      
      :airtable_api_error ->
        {:error, %{
          type: :unauthorized,
          code: "UNAUTHORIZED",
          message: "Invalid API key"
        }}
      
      :network_error ->
        {:error, %{reason: :econnrefused}}
      
      :empty ->
        {:ok, %{"records" => []}}
    end
  end


  # Private helper functions

  defp determine_response_type(path, params) do
    # Check what test scenario is set in the process dictionary
    case Process.get(:airtable_test_scenario) do
      :timeout ->
        :timeout
      
      :malformed_json ->
        :malformed_json
      
      :airtable_api_error ->
        :airtable_api_error
      
      :network_error_with_partial_success ->
        # Return success for first call, then network error
        call_count = Process.get(:airtable_call_count, 0)
        Process.put(:airtable_call_count, call_count + 1)
        if call_count == 0 do
          :success_first_then_fail
        else
          :network_error
        end
      
      :econnrefused ->
        :network_error
      
      :success_large_dataset ->
        # Handle pagination differently based on offset
        if params[:offset] == "second_batch" do
          :success_final_large_batch
        else
          :success_first_large_batch
        end
      
      :mixed_batch ->
        :success_mixed_batch
      
      :large_batch_performance ->
        :success_large_performance_batch
      
      :empty ->
        :empty
      
      _ ->
        # Default behavior for basic tests
        cond do
          params[:offset] == "next_batch_offset" ->
            :success_final_batch
          
          String.contains?(path || "", "stream") ->
            :success_batch
          
          true ->
            :success_batch
        end
    end
  end

  defp generate_test_records(count, id_prefix \\ "TEST") do
    1..count
    |> Enum.map(fn i ->
      %{
        "id" => "rec_#{id_prefix}#{String.pad_leading(to_string(i), 3, "0")}",
        "fields" => %{
          "regulator_id" => "#{id_prefix}#{String.pad_leading(to_string(i), 3, "0")}",
          "offender_name" => "Test Company #{i} Ltd",
          "offender_postcode" => "TE#{i} #{i}ST",
          "agency_code" => "hse",
          "offence_action_type" => if(rem(i, 2) == 0, do: "Court Case", else: "Improvement Notice"),
          "offence_action_date" => "2024-01-#{String.pad_leading(to_string(rem(i, 28) + 1), 2, "0")}",
          "offence_fine" => "#{1000 + i * 100}.00",
          "offence_breaches" => "Test breach #{i}"
        }
      }
    end)
  end

  defp generate_mixed_records(total_count) do
    # Generate half cases, half notices
    cases_count = div(total_count, 2)
    notices_count = total_count - cases_count
    
    cases = 1..cases_count
    |> Enum.map(fn i ->
      %{
        "id" => "rec_case_#{String.pad_leading(to_string(i), 3, "0")}",
        "fields" => %{
          "regulator_id" => "CASE#{String.pad_leading(to_string(i), 3, "0")}",
          "offender_name" => "Case Company #{i} Ltd",
          "offender_postcode" => "C#{i} #{i}SE",
          "agency_code" => "hse",
          "offence_action_type" => "Court Case",
          "offence_action_date" => "2024-01-#{String.pad_leading(to_string(rem(i, 28) + 1), 2, "0")}",
          "offence_fine" => "#{2000 + i * 150}.00",
          "offence_breaches" => "Case breach #{i}"
        }
      }
    end)
    
    notices = 1..notices_count
    |> Enum.map(fn i ->
      %{
        "id" => "rec_notice_#{String.pad_leading(to_string(i), 3, "0")}",
        "fields" => %{
          "regulator_id" => "NOT#{String.pad_leading(to_string(i), 3, "0")}",
          "offender_name" => "Notice Company #{i} Ltd",
          "offender_postcode" => "N#{i} #{i}OT",
          "agency_code" => "hse",
          "offence_action_type" => "Improvement Notice",
          "offence_action_date" => "2024-02-#{String.pad_leading(to_string(rem(i, 28) + 1), 2, "0")}",
          "notice_date" => "2024-02-#{String.pad_leading(to_string(rem(i, 28) + 1), 2, "0")}",
          "operative_date" => "2024-03-#{String.pad_leading(to_string(rem(i, 28) + 1), 2, "0")}",
          "offence_breaches" => "Notice breach #{i}"
        }
      }
    end)
    
    cases ++ notices
  end
end