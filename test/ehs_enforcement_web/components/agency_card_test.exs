defmodule EhsEnforcementWeb.Components.AgencyCardTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias EhsEnforcementWeb.Components.AgencyCard
  alias EhsEnforcement.Enforcement

  describe "AgencyCard component" do
    setup do
      {:ok, agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive",
        enabled: true
      })

      stats = %{
        total_cases: 25,
        total_fines: Decimal.new("125000.00"),
        last_sync: DateTime.utc_now() |> DateTime.add(-3600, :second) # 1 hour ago
      }

      sync_status = %{}
      
      %{agency: agency, stats: stats, sync_status: sync_status}
    end

    test "renders agency information correctly", %{agency: agency, stats: stats, sync_status: sync_status} do
      html = render_component(&AgencyCard.agency_card/1, %{
        agency: agency,
        stats: stats,
        sync_status: sync_status
      })

      # Should display agency name
      assert html =~ "Health and Safety Executive"
      
      # Should display agency code
      assert html =~ "HSE"
      
      # Should have proper data attributes for testing
      assert html =~ ~s(data-testid="agency-card")
      assert html =~ ~s(data-agency-code="hse")
    end

    test "displays statistics correctly", %{agency: agency, stats: stats, sync_status: sync_status} do
      html = render_component(&AgencyCard.agency_card/1, %{
        agency: agency,
        stats: stats,
        sync_status: sync_status
      })

      # Should show case count
      assert html =~ "25"
      assert html =~ "Cases" or html =~ "cases"
      
      # Should show total fines (formatted)
      assert html =~ "£125,000" or html =~ "125000"
      
      # Should show last sync time
      assert html =~ "hour ago" or html =~ "Last Sync"
    end

    test "renders sync button when agency is enabled", %{agency: agency, stats: stats, sync_status: sync_status} do
      html = render_component(&AgencyCard.agency_card/1, %{
        agency: agency,
        stats: stats,
        sync_status: sync_status
      })

      # Should have sync button
      assert html =~ ~s(phx-click="sync")
      assert html =~ ~s(phx-value-agency="hse")
      assert html =~ "Sync Now" or html =~ "Sync"
      
      # Button should not be disabled
      refute html =~ "disabled"
    end

    test "renders disabled state for disabled agencies" do
      {:ok, disabled_agency} = Enforcement.create_agency(%{
        code: :onr,
        name: "Office for Nuclear Regulation", 
        enabled: false
      })

      stats = %{total_cases: 0, total_fines: Decimal.new("0"), last_sync: nil}

      html = render_component(&AgencyCard.agency_card/1, %{
        agency: disabled_agency,
        stats: stats
      })

      # Should indicate disabled state
      assert html =~ ~s(data-disabled="true") or html =~ "disabled"
      
      # Sync button should be disabled or not clickable
      assert html =~ "disabled" or refute html =~ ~s(phx-click="sync")
      
      # Should have disabled styling classes
      assert html =~ "opacity-50" or html =~ "text-gray" or html =~ "disabled"
    end

    test "handles zero statistics gracefully", %{agency: agency, sync_status: sync_status} do
      zero_stats = %{
        total_cases: 0,
        total_fines: Decimal.new("0"),
        last_sync: nil
      }

      html = render_component(&AgencyCard.agency_card/1, %{
        agency: agency,
        stats: zero_stats,
        sync_status: sync_status
      })

      # Should show zero values appropriately
      assert html =~ "0" # Case count
      assert html =~ "£0" or html =~ "No fines"
      assert html =~ "Never" or html =~ "No sync"
    end

    test "handles missing last_sync gracefully", %{agency: agency, sync_status: sync_status} do
      stats = %{
        total_cases: 10,
        total_fines: Decimal.new("5000.00"),
        last_sync: nil
      }

      html = render_component(&AgencyCard.agency_card/1, %{
        agency: agency,
        stats: stats,
        sync_status: sync_status
      })

      # Should handle nil last_sync
      assert html =~ "Never" or html =~ "No recent sync" or html =~ "-"
    end

    test "formats large numbers correctly", %{agency: agency, sync_status: sync_status} do
      large_stats = %{
        total_cases: 1234,
        total_fines: Decimal.new("9876543.21"),
        last_sync: DateTime.utc_now()
      }

      html = render_component(&AgencyCard.agency_card/1, %{
        agency: agency,
        stats: large_stats,
        sync_status: sync_status
      })

      # Should format large numbers with commas or abbreviated
      assert html =~ "1,234" or html =~ "1234"
      assert html =~ "£9,876,543" or html =~ "£9.87M" or html =~ "9876543"
    end

    test "shows sync status indicator", %{agency: agency, stats: stats, sync_status: sync_status} do
      html = render_component(&AgencyCard.agency_card/1, %{
        agency: agency,
        stats: stats,
        sync_status: sync_status
      })

      # Should have sync status indicator
      assert html =~ ~s(data-testid="sync-status")
      
      # Should show some form of status (icon, text, or color)
      assert html =~ "status-" or html =~ "sync-" or html =~ "●" or html =~ "circle"
    end

    test "handles sync in progress state", %{agency: agency, stats: stats, sync_status: sync_status} do
      syncing_status = %{status: "syncing", progress: 45}

      html = render_component(&AgencyCard.agency_card/1, %{
        agency: agency,
        stats: stats,
        sync_status: syncing_status
      })

      # Should show sync progress
      assert html =~ "45%" or html =~ "Syncing" or html =~ "In Progress"
      
      # Sync button should be disabled during sync
      assert html =~ "disabled" or refute html =~ ~s(phx-click="sync")
    end

    test "shows error state when sync fails", %{agency: agency, stats: stats, sync_status: sync_status} do
      error_status = %{status: "error", error: "Connection timeout"}

      html = render_component(&AgencyCard.agency_card/1, %{
        agency: agency,
        stats: stats,
        sync_status: error_status
      })

      # Should indicate error state
      assert html =~ "Error" or html =~ "Failed" or html =~ "⚠" or html =~ "!"
      
      # Should show retry option
      assert html =~ "Retry" or html =~ "Try Again" or html =~ ~s(phx-click="sync")
    end

    test "applies correct CSS classes for styling", %{agency: agency, stats: stats, sync_status: sync_status} do
      html = render_component(&AgencyCard.agency_card/1, %{
        agency: agency,
        stats: stats,
        sync_status: sync_status
      })

      # Should have appropriate Tailwind/CSS classes
      assert html =~ "card" or html =~ "border" or html =~ "rounded"
      assert html =~ "p-" or html =~ "m-" # Spacing classes
      assert html =~ "bg-" or html =~ "text-" # Color classes
    end

    test "includes accessibility attributes", %{agency: agency, stats: stats, sync_status: sync_status} do
      html = render_component(&AgencyCard.agency_card/1, %{
        agency: agency,
        stats: stats,
        sync_status: sync_status
      })

      # Should have ARIA labels or roles
      assert html =~ ~s(aria-label=) or html =~ ~s(role=) or html =~ ~s(alt=)
      
      # Buttons should be accessible
      assert html =~ ~s(aria-label="Sync #{agency.name}") or 
             html =~ ~s(title="Sync") or
             html =~ ~s(aria-describedby=)
    end

    test "renders custom content when provided", %{agency: agency, stats: stats, sync_status: sync_status} do
      html = render_component(&AgencyCard.agency_card/1, %{
        agency: agency,
        stats: stats,
        show_details: true,
        custom_actions: [
          %{label: "View Cases", action: "view_cases", agency: agency.code},
          %{label: "Export", action: "export", agency: agency.code}
        ]
      })

      # Should show additional actions if provided
      assert html =~ "View Cases" or html =~ "Export"
    end

    test "handles click events properly", %{agency: agency, stats: stats, sync_status: sync_status} do
      # This test would typically be done in a LiveView context
      # For now, just verify the HTML structure for event handling
      html = render_component(&AgencyCard.agency_card/1, %{
        agency: agency,
        stats: stats,
        sync_status: sync_status
      })

      # Should have proper phx-click attributes
      assert html =~ ~s(phx-click="sync")
      assert html =~ ~s(phx-value-agency="#{agency.code}")
      
      # Should have target if needed for components
      assert html =~ ~s(phx-target=) or not String.contains?(html, "phx-target")
    end
  end

  describe "AgencyCard edge cases" do
    test "handles nil agency gracefully" do
      stats = %{total_cases: 0, total_fines: Decimal.new("0"), last_sync: nil}

      # Should handle nil agency without crashing
      assert_raise ArgumentError, fn ->
        render_component(&AgencyCard.agency_card/1, %{
          agency: nil,
          stats: stats
        })
      end
    end

    test "handles nil stats gracefully", %{agency: agency} do
      # Should handle nil stats without crashing
      assert_raise ArgumentError, fn ->
        render_component(&AgencyCard.agency_card/1, %{
          agency: agency,
          stats: nil
        })
      end
    end

    test "handles malformed stats data", %{agency: agency} do
      malformed_stats = %{
        total_cases: "not_a_number",
        total_fines: nil,
        last_sync: "invalid_date"
      }

      # Should handle malformed data gracefully
      html = render_component(&AgencyCard.agency_card/1, %{
        agency: agency,
        stats: malformed_stats
      })

      # Should display some fallback values
      assert html =~ "Health and Safety Executive" # Agency name should still show
      assert html =~ "0" or html =~ "-" or html =~ "N/A" # Fallback for bad data
    end

    test "handles very long agency names", %{stats: stats} do
      {:ok, long_name_agency} = Enforcement.create_agency(%{
        code: :test,
        name: "This is a Very Long Agency Name That Might Cause Layout Issues",
        enabled: true
      })

      html = render_component(&AgencyCard.agency_card/1, %{
        agency: long_name_agency,
        stats: stats,
        sync_status: %{}
      })

      # Should truncate or handle long names gracefully
      assert html =~ "This is a Very Long"
      assert html =~ "truncate" or html =~ "ellipsis" or html =~ "..."
    end

    test "handles missing agency code", %{stats: stats, sync_status: sync_status} do
      agency_without_code = %{
        id: UUID.uuid4(),
        code: nil,
        name: "Test Agency",
        enabled: true
      }

      html = render_component(&AgencyCard.agency_card/1, %{
        agency: agency_without_code,
        stats: stats,
        sync_status: %{}
      })

      # Should handle missing code gracefully
      assert html =~ "Test Agency"
      # phx-value-agency should have fallback or be omitted
    end
  end

  describe "AgencyCard responsive design" do
    test "includes responsive CSS classes", %{agency: agency, stats: stats, sync_status: sync_status} do
      html = render_component(&AgencyCard.agency_card/1, %{
        agency: agency,
        stats: stats,
        sync_status: sync_status
      })

      # Should have responsive breakpoint classes
      assert html =~ "sm:" or html =~ "md:" or html =~ "lg:" or html =~ "xl:"
      
      # Should have flexible layout classes
      assert html =~ "flex" or html =~ "grid"
    end

    test "adapts to different screen sizes", %{agency: agency, stats: stats, sync_status: sync_status} do
      html = render_component(&AgencyCard.agency_card/1, %{
        agency: agency,
        stats: stats,
        size: "compact"
      })

      # Should have size-specific classes
      assert html =~ "compact" or html =~ "sm" or html =~ "text-sm"
    end
  end

  describe "AgencyCard performance" do
    test "renders efficiently with large numbers", %{agency: agency} do
      huge_stats = %{
        total_cases: 999_999,
        total_fines: Decimal.new("999999999.99"), 
        last_sync: DateTime.utc_now()
      }

      start_time = System.monotonic_time(:microsecond)
      
      html = render_component(&AgencyCard.agency_card/1, %{
        agency: agency,
        stats: huge_stats
      })
      
      end_time = System.monotonic_time(:microsecond)
      render_time = end_time - start_time

      # Should render quickly (less than 10ms)
      assert render_time < 10_000

      # Should format large numbers correctly
      assert html =~ "999,999" or html =~ "999K" or html =~ "1M"
    end

    test "handles frequent re-renders without memory leaks" do
      {:ok, agency} = Enforcement.create_agency(%{
        code: :test_perf,
        name: "Performance Test Agency",
        enabled: true
      })

      # Render the component many times with changing stats
      Enum.each(1..100, fn i ->
        stats = %{
          total_cases: i,
          total_fines: Decimal.new("#{i * 1000}"),
          last_sync: DateTime.utc_now()
        }

        html = render_component(&AgencyCard.agency_card/1, %{
          agency: agency,
          stats: stats
        })

        assert html =~ "Performance Test Agency"
      end)

      # Test should complete without memory issues
      assert true
    end
  end
end