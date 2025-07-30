defmodule EhsEnforcementWeb.Components.OffendersActionCard do
  @moduledoc """
  Offenders Database action card component for the dashboard.
  
  Displays offender database statistics, provides filtered navigation for top offenders,
  and advanced search functionality. No create functionality - offenders are system-managed.
  Implements the offenders card specification from the dashboard action cards design document.
  """
  
  use Phoenix.Component
  
  import EhsEnforcementWeb.Components.DashboardActionCard
  alias EhsEnforcement.Enforcement

  @doc """
  Renders the Offenders Database action card with live metrics and actions.

  ## Examples

      <.offenders_action_card />

  """
  attr :loading, :boolean, default: false, doc: "Show loading state"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def offenders_action_card(assigns) do
    # Calculate metrics
    assigns = assign_metrics(assigns)
    
    ~H"""
    <.dashboard_action_card 
      title="OFFENDER DATABASE" 
      icon="👥" 
      theme="purple" 
      loading={@loading}
      class={@class}
    >
      <:metrics>
        <.metric_item 
          label="Total Organizations" 
          value={format_number(@total_offenders)} 
        />
        <.metric_item 
          label="Repeat Offenders" 
          value={"#{format_number(@repeat_offenders_count)} (#{@repeat_offenders_percentage}%)"} 
        />
        <.metric_item 
          label="Average Fine" 
          value={format_currency(@average_fine)} 
        />
      </:metrics>
      
      <:actions>
        <.card_action_button phx-click="browse_top_offenders">
          <div class="flex items-center justify-between w-full">
            <span>Browse Top 50</span>
            <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
            </svg>
          </div>
        </.card_action_button>
        
        <.card_secondary_button phx-click="search_offenders">
          <div class="flex items-center justify-between w-full">
            <span>Search Offenders</span>
            <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
            </svg>
          </div>
        </.card_secondary_button>
      </:actions>
    </.dashboard_action_card>
    """
  end

  # Private helper functions

  defp assign_metrics(assigns) do
    try do
      # Get all offenders for statistics
      all_offenders = Enforcement.list_offenders!()
      total_offenders = length(all_offenders)
      
      # Calculate repeat offenders (those with more than 1 total enforcement action)
      repeat_offenders = Enum.filter(all_offenders, fn offender ->
        enforcement_count = (offender.total_cases || 0) + (offender.total_notices || 0)
        enforcement_count > 1
      end)
      
      repeat_offenders_count = length(repeat_offenders)
      repeat_offenders_percentage = if total_offenders > 0 do
        Float.round(repeat_offenders_count / total_offenders * 100, 1)
      else
        0.0
      end
      
      # Calculate average fine amount from all offenders with fines
      offenders_with_fines = Enum.filter(all_offenders, fn offender ->
        total_fines = offender.total_fines || Decimal.new(0)
        Decimal.compare(total_fines, Decimal.new(0)) == :gt
      end)
      
      average_fine = if length(offenders_with_fines) > 0 do
        total_fines_sum = offenders_with_fines
        |> Enum.map(& &1.total_fines || Decimal.new(0))
        |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
        
        Decimal.div(total_fines_sum, length(offenders_with_fines))
      else
        Decimal.new(0)
      end
      
      assigns
      |> assign(:total_offenders, total_offenders)
      |> assign(:repeat_offenders_count, repeat_offenders_count)
      |> assign(:repeat_offenders_percentage, repeat_offenders_percentage)
      |> assign(:average_fine, average_fine)
      
    rescue
      error ->
        require Logger
        Logger.error("Failed to calculate offenders metrics: #{inspect(error)}")
        
        assigns
        |> assign(:total_offenders, 0)
        |> assign(:repeat_offenders_count, 0)
        |> assign(:repeat_offenders_percentage, 0.0)
        |> assign(:average_fine, Decimal.new(0))
    end
  end

  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> format_number_string()
  end

  defp format_number(number) when is_float(number) do
    number
    |> :erlang.float_to_binary([{:decimals, 1}])
    |> format_number_string()
  end

  defp format_number(number) when is_binary(number) do
    format_number_string(number)
  end

  defp format_number(_), do: "0"

  defp format_number_string(number_str) do
    number_str
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp format_currency(amount) when is_struct(amount, Decimal) do
    amount
    |> Decimal.to_string()
    |> String.to_float()
    |> :erlang.float_to_binary([{:decimals, 2}])
    |> then(&"£#{format_number_string(&1)}")
  rescue
    _ -> "£0.00"
  end

  defp format_currency(_), do: "£0.00"
end