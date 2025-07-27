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
    
    # Check if name is empty or only whitespace
    name = String.trim(normalized_attrs[:name] || "")
    if name == "" do
      {:error, %Ash.Error.Invalid{}}
    else
      # Use Ash to find existing offender
      case Enforcement.get_offender_by_name_and_postcode(
        name,
        normalized_attrs[:postcode]
      ) do
      {:ok, offender} -> 
        {:ok, offender}
      
      {:error, %Ash.Error.Query.NotFound{}} ->
        # Try fuzzy search using Ash - only if name has content
        if String.length(name) > 2 do
          # Normalize the search query for better matching
          normalized_search = normalize_company_name(name)
          case Enforcement.search_offenders(normalized_search) do
            {:ok, []} -> 
              # Create new offender using Ash
              create_offender_with_retry(Map.put(normalized_attrs, :name, name))
            
            {:ok, similar_offenders} ->
              # Return best match or create new
              best_match = find_best_match(similar_offenders, Map.put(normalized_attrs, :name, name))
              if best_match do
                {:ok, best_match}
              else
                create_offender_with_retry(Map.put(normalized_attrs, :name, name))
              end
              
            {:error, %Ash.Error.Invalid{}} ->
              # Handle case where search query is invalid (empty, etc.)
              create_offender_with_retry(Map.put(normalized_attrs, :name, name))
              
            error -> error
          end
        else
          # Name too short for fuzzy search, just create
          create_offender_with_retry(Map.put(normalized_attrs, :name, name))
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
    # Remove common punctuation that could interfere with matching
    |> String.replace(~r/[\.,:;!@#$%^&*()]+/, "")
    # Normalize company suffixes
    |> String.replace(~r/\s+(limited|ltd\.?)$/i, " limited")
    |> String.replace(~r/\s+(plc|p\.l\.c\.?)$/i, " plc")
    # Replace multiple spaces with single space
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  def normalize_company_name(_), do: ""
  
  @doc """
  Finds the best match from a list of candidates.
  """
  def find_best_match([], _attrs), do: nil
  
  def find_best_match(candidates, attrs) do
    search_postcode = normalize_postcode(attrs[:postcode])
    
    # Calculate similarity scores and postcode matches
    scored_candidates = candidates
    |> Enum.map(fn candidate ->
      # Calculate similarity if not already present
      similarity = case Map.get(candidate, :similarity) do
        nil -> calculate_similarity(get_name(candidate), attrs[:name] || "")
        existing -> existing
      end
      
      # Check if postcode matches
      candidate_postcode = normalize_postcode(get_postcode(candidate))
      postcode_match = candidate_postcode == search_postcode
      
      # If we have a search postcode and the candidate has a different postcode,
      # and they're both non-nil, then don't match (treat as different entities)
      postcode_conflict = search_postcode != nil && 
                         candidate_postcode != nil && 
                         candidate_postcode != search_postcode
      
      # Don't match if there's a postcode conflict (same name, different locations)
      if postcode_conflict do
        Map.put(candidate, :similarity, 0.0)  # Force no match
      else
        # Only boost similarity if it was calculated (not pre-provided)
        adjusted_similarity = case Map.get(candidate, :similarity) do
          nil -> 
            # We calculated it, so boost for postcode match
            if postcode_match && similarity > 0.6 do
              min(similarity + 0.15, 1.0)  # Boost by 0.15, but cap at 1.0
            else
              similarity
            end
          existing -> 
            # Pre-provided similarity score, don't modify it
            existing
        end
        
        candidate
        |> Map.put(:similarity, adjusted_similarity)
        |> Map.put(:postcode_match, postcode_match)
      end
    end)
    |> Enum.filter(fn candidate -> Map.get(candidate, :similarity, 0) > 0.7 end)
    |> Enum.sort_by(fn candidate ->
      # Sort by similarity desc, then postcode match desc
      similarity = Map.get(candidate, :similarity, 0)
      postcode_match = Map.get(candidate, :postcode_match, false)
      {similarity, if(postcode_match, do: 1, else: 0)}
    end, :desc)
    
    case scored_candidates do
      [] -> nil
      [best | _] -> best
    end
  end
  
  # Private functions
  
  # Get name from candidate (works with both Offender structs and plain maps)
  defp get_name(%{name: name}), do: name
  defp get_name(candidate), do: Map.get(candidate, :name, "")
  
  # Get postcode from candidate (works with both Offender structs and plain maps)  
  defp get_postcode(%{postcode: postcode}), do: postcode
  defp get_postcode(candidate), do: Map.get(candidate, :postcode)
  
  defp normalize_attrs(attrs) when is_map(attrs) do
    # Normalize postcode, ensure name is present as atom or string key
    attrs
    |> Map.update(:postcode, nil, &normalize_postcode/1)
    |> then(fn normalized_attrs ->
      # Ensure we have a name field (handle both string and atom keys)
      name = normalized_attrs[:name] || normalized_attrs["name"] || ""
      Map.put(normalized_attrs, :name, name)
    end)
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
    # Normalize both strings for comparison
    norm1 = normalize_company_name(str1 || "")
    norm2 = normalize_company_name(str2 || "")
    
    if norm1 == norm2 do
      1.0
    else
      # Use a combination of Jaccard similarity and length ratio
      jaccard = jaccard_similarity(norm1, norm2)
      
      # Boost score for very similar names (accounting for common variations)
      if String.jaro_distance(norm1, norm2) > 0.85 do
        max(jaccard, 0.9)
      else
        jaccard
      end
    end
  end
  
  defp jaccard_similarity(str1, str2) do
    # Split into normalized tokens for better matching
    tokens1 = str1 |> String.split(~r/\s+/) |> MapSet.new()
    tokens2 = str2 |> String.split(~r/\s+/) |> MapSet.new()
    
    intersection = MapSet.intersection(tokens1, tokens2) |> MapSet.size()
    union = MapSet.union(tokens1, tokens2) |> MapSet.size()
    
    if union == 0, do: 0.0, else: intersection / union
  end
end