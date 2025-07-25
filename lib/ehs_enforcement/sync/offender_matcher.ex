defmodule EhsEnforcement.Sync.OffenderMatcher do
  @moduledoc """
  Handles finding or creating offenders with deduplication logic.
  """
  
  alias EhsEnforcement.Enforcement
  require Logger
  
  @doc """
  Finds or creates an offender using Ash queries
  """
  def find_or_create_offender(attrs) do
    normalized_attrs = normalize_attrs(attrs)
    
    # Check if name is empty
    if normalized_attrs.name == "" do
      {:error, %Ash.Error.Invalid{}}
    else
      # Use Ash to find existing offender
      case Enforcement.get_offender_by_name_and_postcode(
        normalized_attrs.name,
        normalized_attrs[:postcode]
      ) do
      {:ok, offender} -> 
        {:ok, offender}
      
      {:error, %Ash.Error.Query.NotFound{}} ->
        # Try fuzzy search using Ash
        case Enforcement.search_offenders(normalized_attrs.name) do
          {:ok, []} -> 
            # Create new offender using Ash
            create_offender_with_retry(normalized_attrs)
          
          {:ok, similar_offenders} ->
            # Return best match or create new
            best_match = find_best_match(similar_offenders, normalized_attrs)
            if best_match do
              {:ok, best_match}
            else
              create_offender_with_retry(normalized_attrs)
            end
        end
      
        error -> error
      end
    end
  end
  
  @doc """
  Normalizes company names to standard format.
  """
  def normalize_company_name(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/\s+(limited|ltd\.?)$/i, " limited")
    |> String.replace(~r/\s+(plc|p\.l\.c\.?)$/i, " plc")
    |> String.replace(~r/\s+/, " ")  # Replace multiple spaces with single space
    |> String.trim()
  end

  def normalize_company_name(_), do: ""
  
  @doc """
  Finds the best match from a list of candidates.
  """
  def find_best_match([], _attrs), do: nil
  
  def find_best_match(candidates, attrs) do
    # Sort by similarity score and postcode match
    candidates
    |> Enum.map(fn candidate ->
      # Calculate similarity if not already present
      similarity = case Map.get(candidate, :similarity) do
        nil -> calculate_similarity(get_name(candidate), attrs.name)
        existing -> existing
      end
      Map.put(candidate, :similarity, similarity)
    end)
    |> Enum.sort_by(fn candidate ->
      postcode_match = if normalize_postcode(get_postcode(candidate)) == normalize_postcode(attrs[:postcode]), do: 1, else: 0
      similarity = Map.get(candidate, :similarity, 0)
      {similarity, postcode_match}
    end, :desc)
    |> List.first()
    |> then(fn
      nil -> nil
      candidate -> if Map.get(candidate, :similarity, 0) > 0.7, do: candidate, else: nil
    end)
  end
  
  # Private functions
  
  # Get name from candidate (works with both Offender structs and plain maps)
  defp get_name(%{name: name}), do: name
  defp get_name(candidate), do: Map.get(candidate, :name, "")
  
  # Get postcode from candidate (works with both Offender structs and plain maps)  
  defp get_postcode(%{postcode: postcode}), do: postcode
  defp get_postcode(candidate), do: Map.get(candidate, :postcode)
  
  defp normalize_attrs(attrs) when is_map(attrs) do
    attrs
    |> Map.update(:name, "", &normalize_company_name/1)
    |> Map.update(:postcode, nil, &normalize_postcode/1)
  end
  
  defp normalize_postcode(nil), do: nil
  defp normalize_postcode(postcode) when is_binary(postcode) do
    postcode |> String.trim() |> String.upcase()
  end
  
  defp create_offender_with_retry(attrs) do
    case Enforcement.create_offender(attrs) do
      {:ok, offender} ->
        {:ok, offender}
        
      {:error, %Ash.Error.Invalid{}} ->
        # Handle race condition - try to find again
        case Enforcement.get_offender_by_name_and_postcode(attrs.name, attrs[:postcode]) do
          {:ok, offender} -> {:ok, offender}
          error -> error
        end
        
      error ->
        error
    end
  end
  
  defp calculate_similarity(str1, str2) do
    # Simple similarity calculation
    if str1 == str2 do
      1.0
    else
      # Basic character overlap ratio
      chars1 = String.graphemes(str1) |> MapSet.new()
      chars2 = String.graphemes(str2) |> MapSet.new()
      
      intersection = MapSet.intersection(chars1, chars2) |> MapSet.size()
      union = MapSet.union(chars1, chars2) |> MapSet.size()
      
      if union == 0, do: 0.0, else: intersection / union
    end
  end
end