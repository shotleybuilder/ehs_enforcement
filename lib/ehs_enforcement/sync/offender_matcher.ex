defmodule EhsEnforcement.Sync.OffenderMatcher do
  @moduledoc """
  Handles finding or creating offenders with deduplication logic.
  """
  
  alias EhsEnforcement.Enforcement
  
  @doc """
  Finds or creates an offender using Ash queries
  """
  def find_or_create_offender(attrs) do
    normalized_attrs = normalize_attrs(attrs)
    
    # Use Ash to find existing offender
    case Enforcement.get_offender_by_name_and_postcode(
      normalized_attrs.name,
      normalized_attrs[:postcode]
    ) do
      {:ok, offender} -> 
        {:ok, offender}
      
      {:error, :not_found} ->
        # Try fuzzy search using Ash
        case Enforcement.search_offenders(normalized_attrs.name) do
          {:ok, []} -> 
            # Create new offender using Ash
            Enforcement.create_offender(normalized_attrs)
          
          {:ok, similar_offenders} ->
            # Return best match or create new
            find_best_match(similar_offenders, normalized_attrs)
        end
      
      error -> error
    end
  end
  
  defp normalize_attrs(attrs) when is_map(attrs) do
    Map.update(attrs, :name, "", &normalize_company_name/1)
  end
  
  defp normalize_company_name(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/\s+(limited|ltd\.?)$/i, " limited")
    |> String.replace(~r/\s+(plc|p\.l\.c\.?)$/i, " plc")
    |> String.trim()
  end

  defp normalize_company_name(name), do: name
  
  defp find_best_match(similar_offenders, attrs) do
    # For now, just return the first match or create new
    # Could implement more sophisticated matching logic here
    case similar_offenders do
      [offender | _] -> {:ok, offender}
      [] -> Enforcement.create_offender(attrs)
    end
  end
end