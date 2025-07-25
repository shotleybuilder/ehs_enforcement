defmodule EhsEnforcementWeb.CaseLive.CSVExport do
  @moduledoc """
  Handles CSV export functionality for case data
  """

  alias EhsEnforcement.Enforcement

  @csv_headers [
    "Case ID",
    "Agency", 
    "Agency Code",
    "Offender Name",
    "Local Authority",
    "Postcode",
    "Offense Date",
    "Fine Amount",
    "Offense Breaches",
    "Total Notices",
    "Total Breaches",
    "Last Synced",
    "Created At"
  ]

  @doc """
  Export cases to CSV format based on current filters
  """
  def export_cases(filters \\ %{}, sort_by \\ :offence_action_date, sort_dir \\ :desc) do
    # Build query options without pagination for full export
    query_opts = [
      filter: build_ash_filter(filters),
      sort: build_sort_options(sort_by, sort_dir),
      load: [:offender, :agency]
    ]

    try do
      cases = Enforcement.list_cases!(query_opts)
      generate_csv(cases)
    rescue
      error ->
        {:error, "Failed to export cases: #{inspect(error)}"}
    end
  end

  @doc """
  Export a single case to CSV format
  """
  def export_case(case_id) do
    try do
      case_record = Enforcement.get_case!(case_id, load: [:offender, :agency])
      generate_csv([case_record])
    rescue
      Ash.Error.Query.NotFound ->
        {:error, "Case not found"}
      
      error ->
        {:error, "Failed to export case: #{inspect(error)}"}
    end
  end

  @doc """
  Generate CSV content from list of cases
  """
  def generate_csv(cases) when is_list(cases) do
    csv_content = 
      [@csv_headers | Enum.map(cases, &case_to_csv_row/1)]
      |> Enum.map(&Enum.join(&1, ","))
      |> Enum.join("\n")
    
    {:ok, csv_content}
  end

  @doc """
  Generate filename for CSV export
  """
  def generate_filename(export_type \\ :all, identifier \\ nil) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic) |> String.slice(0, 8)
    
    case export_type do
      :single when identifier != nil ->
        "case_#{identifier}_#{timestamp}.csv"
        
      :filtered ->
        "cases_filtered_#{timestamp}.csv"
        
      _ ->
        "cases_export_#{timestamp}.csv"
    end
  end

  # Private functions

  defp case_to_csv_row(case_record) do
    [
      escape_csv_field(case_record.regulator_id || ""),
      escape_csv_field(case_record.agency.name || ""),
      escape_csv_field(to_string(case_record.agency.code) || ""),
      escape_csv_field(case_record.offender.name || ""),
      escape_csv_field(case_record.offender.local_authority || ""),
      escape_csv_field(case_record.offender.postcode || ""),
      format_date_for_csv(case_record.offence_action_date),
      format_currency_for_csv(case_record.offence_fine),
      escape_csv_field(case_record.offence_breaches || ""),
      0, # notices count (not loaded)
      0, # breaches count (not loaded)
      format_datetime_for_csv(case_record.last_synced_at),
      format_datetime_for_csv(case_record.inserted_at)
    ]
  end

  defp escape_csv_field(field) when is_binary(field) do
    # Handle CSV injection prevention
    sanitized = String.replace(field, ["=", "+", "-", "@"], "")
    
    if String.contains?(sanitized, [",", "\"", "\n", "\r"]) do
      "\"#{String.replace(sanitized, "\"", "\"\"")}\""
    else
      sanitized
    end
  end

  defp escape_csv_field(field), do: to_string(field)

  defp format_date_for_csv(date) when is_struct(date, Date) do
    Date.to_iso8601(date)
  end

  defp format_date_for_csv(_), do: ""

  defp format_datetime_for_csv(datetime) when is_struct(datetime, DateTime) do
    DateTime.to_iso8601(datetime)
  end

  defp format_datetime_for_csv(_), do: ""

  defp format_currency_for_csv(amount) when is_struct(amount, Decimal) do
    Decimal.to_string(amount)
  end

  defp format_currency_for_csv(_), do: "0.00"

  defp count_associations(associations) when is_list(associations) do
    length(associations)
  end

  defp count_associations(_), do: 0

  # Copy filter and sort building logic from Index module
  defp build_ash_filter(filters) do
    Enum.reduce(filters, [], fn
      {:agency_id, id}, acc when is_binary(id) and id != "" ->
        [{:agency_id, id} | acc]
      
      {:date_from, date}, acc when is_binary(date) and date != "" ->
        case Date.from_iso8601(date) do
          {:ok, parsed_date} -> [{:offence_action_date, [greater_than_or_equal_to: parsed_date]} | acc]
          _ -> acc
        end
      
      {:date_to, date}, acc when is_binary(date) and date != "" ->
        case Date.from_iso8601(date) do
          {:ok, parsed_date} -> [{:offence_action_date, [less_than_or_equal_to: parsed_date]} | acc]
          _ -> acc
        end
      
      {:min_fine, amount}, acc when is_binary(amount) and amount != "" ->
        case Decimal.parse(amount) do
          {decimal_amount, _} -> [{:offence_fine, [greater_than_or_equal_to: decimal_amount]} | acc]
          :error -> acc
        end
      
      {:max_fine, amount}, acc when is_binary(amount) and amount != "" ->
        case Decimal.parse(amount) do
          {decimal_amount, _} -> [{:offence_fine, [less_than_or_equal_to: decimal_amount]} | acc]
          :error -> acc
        end
      
      {:search, query}, acc when is_binary(query) and query != "" ->
        search_conditions = [
          [offender: [name: [ilike: "%#{query}%"]]],
          [regulator_id: [ilike: "%#{query}%"]],
          [offence_breaches: [ilike: "%#{query}%"]]
        ]
        [{:or, search_conditions} | acc]
      
      _, acc -> acc
    end)
  end

  defp build_sort_options(sort_by, sort_dir) do
    case {sort_by, sort_dir} do
      {:offender_name, dir} ->
        [offender: [name: dir]]
      
      {:agency_name, dir} ->
        [agency: [name: dir]]
      
      {field, dir} when field in [:offence_action_date, :offence_fine, :regulator_id] ->
        [{field, dir}]
      
      _ ->
        [offence_action_date: :desc]
    end
  end
end