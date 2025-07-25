defmodule EhsEnforcementWeb.Components.AgencyCard do
  use Phoenix.Component

  def agency_card(assigns) do
    ~H"""
    <div class="agency-card bg-white rounded-lg shadow p-6" data-testid="agency-card" data-agency-code={@agency.code}>
      <div class="flex justify-between items-start mb-4">
        <div>
          <h3 class="text-lg font-semibold text-gray-900"><%= @agency.name %></h3>
          <span class={[
            "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium mt-2",
            @agency.active && "bg-green-100 text-green-800",
            !@agency.active && "bg-gray-100 text-gray-800"
          ]}>
            <%= if @agency.active, do: "Active", else: "Inactive" %>
          </span>
        </div>
        <%= if @agency.active do %>
          <button
            phx-click="sync_agency"
            phx-value-agency={@agency.code}
            data-testid={"sync-button-#{@agency.code}"}
            class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            disabled={sync_in_progress?(@sync_status)}
          >
            <%= if sync_in_progress?(@sync_status) do %>
              <svg class="animate-spin -ml-0.5 mr-2 h-4 w-4 text-gray-700" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              Syncing...
            <% else %>
              <svg class="-ml-0.5 mr-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z" clip-rule="evenodd" />
              </svg>
              Sync Now
            <% end %>
          </button>
        <% end %>
      </div>

      <div class="grid grid-cols-2 gap-4">
        <div>
          <p class="text-sm text-gray-500">Total Cases</p>
          <p class="text-2xl font-semibold text-gray-900" data-testid={"case-count-#{@agency.code}"}>
            <%= @stats[:case_count] || 0 %>
          </p>
        </div>
        <div>
          <p class="text-sm text-gray-500">Percentage</p>
          <p class="text-2xl font-semibold text-gray-900">
            <%= @stats[:percentage] || 0 %>%
          </p>
        </div>
      </div>

      <%= if @stats[:last_sync] do %>
        <div class="mt-4 pt-4 border-t border-gray-200">
          <p class="text-sm text-gray-500">
            Last synced: <span class="text-gray-700"><%= format_datetime(@stats[:last_sync]) %></span>
          </p>
        </div>
      <% end %>

      <%= if sync_in_progress?(@sync_status) do %>
        <div class="mt-4">
          <div class="flex justify-between text-sm text-gray-600 mb-1">
            <span>Sync Progress</span>
            <span><%= @sync_status.progress || 0 %>%</span>
          </div>
          <div class="w-full bg-gray-200 rounded-full h-2">
            <div 
              class="bg-indigo-600 h-2 rounded-full transition-all duration-300 ease-out"
              style={"width: #{@sync_status.progress || 0}%"}
              data-testid="sync-progress-bar"
            >
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp sync_in_progress?(nil), do: false
  defp sync_in_progress?(%{status: "syncing"}), do: true
  defp sync_in_progress?(_), do: false

  defp format_datetime(nil), do: "Never"
  defp format_datetime(datetime) do
    # Simple formatting - in production you'd use a proper date formatting library
    case DateTime.from_naive(datetime, "Etc/UTC") do
      {:ok, dt} -> 
        "#{dt.day}/#{dt.month}/#{dt.year} #{String.pad_leading(to_string(dt.hour), 2, "0")}:#{String.pad_leading(to_string(dt.minute), 2, "0")}"
      _ -> 
        "Invalid date"
    end
  end
end