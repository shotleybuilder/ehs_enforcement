defmodule EhsEnforcementWeb.Components.OffenderTableTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest

  alias EhsEnforcement.Enforcement
  alias EhsEnforcementWeb.Components.OffenderTable

  describe "OffenderTable component" do
    setup do
      # Create test agencies
      {:ok, hse_agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive",
        enabled: true
      })

      # Create test offenders with different characteristics
      {:ok, high_risk_offender} = Enforcement.create_offender(%{
        name: "High Risk Manufacturing Ltd",
        local_authority: "Manchester City Council",
        postcode: "M1 1AA",
        industry: "Manufacturing",
        business_type: :limited_company,
        total_cases: 8,
        total_notices: 12,
        total_fines: Decimal.new("500000"),
        first_seen_date: ~D[2019-03-15],
        last_seen_date: ~D[2024-01-20]
      })

      {:ok, moderate_offender} = Enforcement.create_offender(%{
        name: "Moderate Corp",
        local_authority: "Birmingham City Council",
        postcode: "B2 2BB",
        industry: "Chemical Processing",
        business_type: :plc,
        total_cases: 3,
        total_notices: 4,
        total_fines: Decimal.new("125000"),
        first_seen_date: ~D[2021-06-10],
        last_seen_date: ~D[2023-11-15]
      })

      {:ok, low_risk_offender} = Enforcement.create_offender(%{
        name: "Small Business Ltd",
        local_authority: "Leeds City Council",
        postcode: "LS3 3CC",
        industry: "Retail",
        business_type: :limited_company,
        total_cases: 1,
        total_notices: 1,
        total_fines: Decimal.new("15000"),
        first_seen_date: ~D[2023-08-05],
        last_seen_date: ~D[2023-08-05]
      })

      offenders = [high_risk_offender, moderate_offender, low_risk_offender]

      %{
        hse_agency: hse_agency,
        offenders: offenders,
        high_risk_offender: high_risk_offender,
        moderate_offender: moderate_offender,
        low_risk_offender: low_risk_offender
      }
    end

    test "renders offender table with all columns", %{offenders: offenders} do
      html = render_component(OffenderTable, %{offenders: offenders})

      # Should have table headers
      assert html =~ "Name"
      assert html =~ "Industry"
      assert html =~ "Local Authority"
      assert html =~ "Cases"
      assert html =~ "Notices" 
      assert html =~ "Total Fines"
      assert html =~ "Risk Level"
      assert html =~ "Last Activity"
    end

    test "displays offender data correctly", %{offenders: offenders, high_risk_offender: high_risk_offender} do
      html = render_component(OffenderTable, %{offenders: offenders})

      # Should show offender details
      assert html =~ high_risk_offender.name
      assert html =~ "Manchester City Council"
      assert html =~ "Manufacturing"
      assert html =~ "8" # total_cases
      assert html =~ "12" # total_notices
      assert html =~ "£500,000" # formatted total_fines
    end

    test "applies correct risk level indicators", %{offenders: offenders, high_risk_offender: high_risk_offender, low_risk_offender: low_risk_offender} do
      html = render_component(OffenderTable, %{offenders: offenders})

      # High risk offender (8+ cases, £500k+ fines)
      assert html =~ ~r/<.*data-offender-id="#{high_risk_offender.id}".*data-risk-level="high"/
      assert html =~ "High Risk"

      # Low risk offender (1 case, £15k fines)
      assert html =~ ~r/<.*data-offender-id="#{low_risk_offender.id}".*data-risk-level="low"/
      assert html =~ "Low Risk"
    end

    test "shows repeat offender indicators", %{offenders: offenders, high_risk_offender: high_risk_offender} do
      html = render_component(OffenderTable, %{offenders: offenders})

      # Should mark repeat offenders (multiple cases)
      assert html =~ ~r/<.*data-offender-id="#{high_risk_offender.id}".*data-repeat-offender="true"/
      assert html =~ "Repeat"
    end

    test "formats monetary values correctly", %{offenders: offenders} do
      html = render_component(OffenderTable, %{offenders: offenders})

      # Should format large amounts with commas
      assert html =~ "£500,000"
      assert html =~ "£125,000"
      assert html =~ "£15,000"
    end

    test "handles empty offender list", %{} do
      html = render_component(OffenderTable, %{offenders: []})

      assert html =~ "No offenders found"
      assert html =~ "No enforcement data available"
    end

    test "sorts offenders by specified column", %{offenders: offenders} do
      # Sort by total_fines descending
      html = render_component(OffenderTable, %{
        offenders: offenders,
        sort_by: :total_fines,
        sort_order: :desc
      })

      # Should maintain table structure with sorted data
      assert html =~ "<table"
      assert html =~ "Name" # Headers still present
      
      # Note: Actual sorting would be handled by the parent LiveView
      # Component just displays the data in the order provided
    end

    test "includes clickable rows for navigation", %{offenders: offenders, high_risk_offender: high_risk_offender} do
      html = render_component(OffenderTable, %{offenders: offenders})

      # Should have clickable rows linking to offender detail
      assert html =~ ~r/<tr[^>]*data-offender-id="#{high_risk_offender.id}"[^>]*>/
      assert html =~ ~r/href="\/offenders\/#{high_risk_offender.id}"/
    end

    test "displays business type information", %{offenders: offenders} do
      html = render_component(OffenderTable, %{offenders: offenders})

      # Should show business types
      assert html =~ "Limited Company"
      assert html =~ "PLC"
    end

    test "shows enforcement activity timeline indicators", %{offenders: offenders, high_risk_offender: high_risk_offender} do
      html = render_component(OffenderTable, %{offenders: offenders})

      # Should show first/last seen dates or activity span
      assert html =~ "2019" # first_seen_date year
      assert html =~ "2024" # last_seen_date year
      
      # Should indicate enforcement span
      assert html =~ ~r/data-activity-span="[^"]*"/
    end

    test "applies appropriate CSS classes for styling", %{offenders: offenders} do
      html = render_component(OffenderTable, %{offenders: offenders})

      # Should have proper table styling classes
      assert html =~ ~r/class="[^"]*table[^"]*"/
      assert html =~ ~r/class="[^"]*offender-table[^"]*"/
      
      # Should have row styling
      assert html =~ ~r/class="[^"]*offender-row[^"]*"/
    end

    test "includes proper accessibility attributes", %{offenders: offenders} do
      html = render_component(OffenderTable, %{offenders: offenders})

      # Should have table accessibility
      assert html =~ ~r/role="table"/
      assert html =~ ~r/role="columnheader"/
      assert html =~ ~r/role="row"/
      assert html =~ ~r/role="cell"/
      
      # Should have sortable column indicators
      assert html =~ ~r/aria-sort/
    end

    test "handles loading state", %{} do
      html = render_component(OffenderTable, %{
        offenders: [],
        loading: true
      })

      # Should show loading indicator
      assert html =~ "Loading"
      assert html =~ "offender-table-loading"
    end

    test "supports pagination display", %{offenders: offenders} do
      html = render_component(OffenderTable, %{
        offenders: offenders,
        page_info: %{
          current_page: 1,
          total_pages: 3,
          total_count: 25
        }
      })

      # Should show pagination info
      assert html =~ "Page 1 of 3"
      assert html =~ "25 total"
    end

    test "displays industry-specific styling", %{offenders: offenders} do
      html = render_component(OffenderTable, %{offenders: offenders})

      # Should apply industry-specific classes or indicators
      assert html =~ ~r/data-industry="Manufacturing"/
      assert html =~ ~r/data-industry="Chemical Processing"/
      assert html =~ ~r/data-industry="Retail"/
    end

    test "shows enforcement trend indicators", %{offenders: offenders, high_risk_offender: high_risk_offender} do
      html = render_component(OffenderTable, %{offenders: offenders})

      # Should indicate if enforcement is recent/ongoing
      assert html =~ ~r/data-recent-activity="true"/ # For offenders with 2024 activity
      
      # Should show trend arrows or indicators
      assert html =~ "trending" || html =~ "arrow" || html =~ "↗" || html =~ "↘"
    end
  end

  describe "OffenderTable component interactions" do
    setup do
      {:ok, offender} = Enforcement.create_offender(%{
        name: "Interactive Corp",
        local_authority: "Test Council",
        total_cases: 2,
        total_notices: 3,
        total_fines: Decimal.new("75000")
      })

      %{offender: offender}
    end

    test "handles row click events", %{offender: offender} do
      # This would be tested in the parent LiveView, but we ensure
      # the component provides the necessary data attributes
      html = render_component(OffenderTable, %{offenders: [offender]})

      assert html =~ ~r/data-offender-id="#{offender.id}"/
      assert html =~ ~r/phx-click|data-clickable/
    end

    test "supports row hover states", %{offender: offender} do
      html = render_component(OffenderTable, %{offenders: [offender]})

      # Should have hover styling classes
      assert html =~ ~r/hover:|offender-row-hover/
    end

    test "displays contextual actions", %{offender: offender} do
      html = render_component(OffenderTable, %{
        offenders: [offender],
        show_actions: true
      })

      # Should show action buttons or dropdowns
      assert html =~ "Actions" || html =~ "⋮" || html =~ "dropdown"
      assert html =~ "View Details"
    end
  end

  describe "OffenderTable component responsive design" do
    setup do
      {:ok, offender} = Enforcement.create_offender(%{
        name: "Responsive Corp",
        local_authority: "Test Council",
        total_cases: 1,
        total_notices: 2,
        total_fines: Decimal.new("50000")
      })

      %{offender: offender}
    end

    test "applies responsive CSS classes", %{offender: offender} do
      html = render_component(OffenderTable, %{offenders: [offender]})

      # Should have responsive table classes
      assert html =~ ~r/responsive|mobile|tablet|desktop/
      assert html =~ ~r/sm:|md:|lg:/  # Tailwind responsive prefixes
    end

    test "supports mobile card layout option", %{offender: offender} do
      html = render_component(OffenderTable, %{
        offenders: [offender],
        mobile_layout: :cards
      })

      # Should switch to card layout on mobile
      assert html =~ "offender-card" || html =~ "mobile-card"
    end

    test "handles column visibility on small screens", %{offender: offender} do
      html = render_component(OffenderTable, %{offenders: [offender]})

      # Should hide less important columns on mobile
      assert html =~ ~r/hidden.*sm:table-cell|mobile-hidden/
    end
  end
end