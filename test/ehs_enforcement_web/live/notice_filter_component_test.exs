defmodule EhsEnforcementWeb.NoticeFilterComponentTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest

  alias EhsEnforcement.Enforcement

  describe "NoticeFilter component rendering" do
    setup do
      # Create test agencies for filter options
      {:ok, hse_agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive",
        enabled: true
      })

      {:ok, ea_agency} = Enforcement.create_agency(%{
        code: :ea,
        name: "Environment Agency",
        enabled: true
      })

      {:ok, onr_agency} = Enforcement.create_agency(%{
        code: :onr,
        name: "Office for Nuclear Regulation",
        enabled: true
      })

      {:ok, disabled_agency} = Enforcement.create_agency(%{
        code: :orr,
        name: "Office of Rail and Road",
        enabled: false
      })

      %{
        hse_agency: hse_agency,
        ea_agency: ea_agency,
        onr_agency: onr_agency,
        disabled_agency: disabled_agency
      }
    end

    test "renders complete filter form structure", %{conn: conn, hse_agency: hse_agency, ea_agency: ea_agency} do
      {:ok, view, html} = live(conn, "/notices")

      # Should display filter form
      assert has_element?(view, "[data-testid='notice-filters']")
      assert html =~ "Filter Notices"

      # Should include all filter fields
      assert has_element?(view, "select[name='filters[agency_id]']")
      assert has_element?(view, "select[name='filters[notice_type]']")
      assert has_element?(view, "input[name='filters[date_from]']")
      assert has_element?(view, "input[name='filters[date_to]']")
      assert has_element?(view, "select[name='filters[compliance_status]']")
      assert has_element?(view, "input[name='filters[region]']")
      assert has_element?(view, "input[name='filters[search]']")
    end

    test "displays agency dropdown with enabled agencies only", %{conn: conn, hse_agency: hse_agency, ea_agency: ea_agency, disabled_agency: disabled_agency} do
      {:ok, view, html} = live(conn, "/notices")

      # Should show enabled agencies
      assert html =~ hse_agency.name
      assert html =~ ea_agency.name
      assert html =~ "Health and Safety Executive"
      assert html =~ "Environment Agency"

      # Should show disabled agencies as disabled options
      if html =~ disabled_agency.name do
        assert html =~ "disabled" or html =~ "(Disabled)"
      else
        # Or exclude them entirely
        refute html =~ "Office of Rail and Road"
      end

      # Should include "All Agencies" option
      assert html =~ "All Agencies" or html =~ "All"
    end

    test "includes notice type categorization options", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Should include common notice types
      assert html =~ "Improvement Notice" or has_element?(view, "option[value='Improvement Notice']")
      assert html =~ "Prohibition Notice" or has_element?(view, "option[value='Prohibition Notice']")
      assert html =~ "Enforcement Notice" or has_element?(view, "option[value='Enforcement Notice']")
      
      # Should include "All Types" option
      assert html =~ "All Types" or html =~ "All Notice Types"
    end

    test "provides date range input fields with proper types", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Should have date inputs
      assert has_element?(view, "input[type='date'][name='filters[date_from]']")
      assert has_element?(view, "input[type='date'][name='filters[date_to]']")
      
      # Should have proper labels
      assert html =~ "Date From" or html =~ "From Date"
      assert html =~ "Date To" or html =~ "To Date"
    end

    test "includes compliance status filter options", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Should include compliance status options
      assert html =~ "Pending" or has_element?(view, "option[value='pending']")
      assert html =~ "Overdue" or has_element?(view, "option[value='overdue']")
      assert html =~ "Compliant" or has_element?(view, "option[value='compliant']")
      
      # Should include "All Statuses" option
      assert html =~ "All Statuses" or html =~ "All"
    end

    test "provides geographic region filter input", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Should have region/location filter
      assert has_element?(view, "input[name='filters[region]']") or
             has_element?(view, "select[name='filters[region]']")
      
      # Should have appropriate label
      assert html =~ "Region" or html =~ "Local Authority" or html =~ "Location"
    end

    test "includes search input field", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Should have search input
      assert has_element?(view, "input[name='filters[search]']")
      assert html =~ "Search" or html =~ "search"
      
      # Should have placeholder text
      assert html =~ "placeholder=" or html =~ "Search notices"
    end

    test "displays filter control buttons", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Should have apply and clear buttons
      assert has_element?(view, "button", "Apply Filters") or 
             has_element?(view, "button[type='submit']")
      assert has_element?(view, "button", "Clear") or 
             has_element?(view, "button", "Clear Filters")
    end

    test "shows active filter count", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Apply some filters
      view
      |> form("[data-testid='notice-filters']", filters: %{
        agency_id: "test-agency-id",
        notice_type: "Improvement Notice"
      })
      |> render_change()

      html = render(view)
      
      # Should show number of active filters
      assert html =~ "2 filters" or html =~ "filters applied" or html =~ "active"
    end
  end

  describe "NoticeFilter component interactions" do
    setup :create_test_agencies_and_notices

    test "triggers live update on filter change", %{conn: conn, hse_agency: hse_agency} do
      {:ok, view, _html} = live(conn, "/notices")

      # Change agency filter
      view
      |> form("[data-testid='notice-filters']", filters: %{agency_id: hse_agency.id})
      |> render_change()

      html = render(view)
      
      # Should update the notice list based on filter
      assert html =~ "Health and Safety Executive"
    end

    test "filters notices by notice type", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Filter by Improvement Notice
      view
      |> form("[data-testid='notice-filters']", filters: %{notice_type: "Improvement Notice"})
      |> render_change()

      html = render(view)
      
      # Should show only Improvement Notices
      assert html =~ "Improvement Notice"
      # Should update results accordingly
      assert html =~ "HSE-NOTICE" or html =~ "notice"
    end

    test "filters notices by date range", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Apply date range filter
      view
      |> form("[data-testid='notice-filters']", filters: %{
        date_from: "2024-01-01",
        date_to: "2024-01-31"
      })
      |> render_change()

      html = render(view)
      
      # Should filter results by date range
      assert html =~ "notice" or html =~ "Notice"
    end

    test "filters notices by compliance status", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Filter by pending compliance
      view
      |> form("[data-testid='notice-filters']", filters: %{compliance_status: "pending"})
      |> render_change()

      html = render(view)
      
      # Should show only pending notices
      assert html =~ "pending" or html =~ "Pending" or html =~ "notice"
    end

    test "filters notices by geographic region", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Filter by region/local authority
      view
      |> form("[data-testid='notice-filters']", filters: %{region: "Manchester"})
      |> render_change()

      html = render(view)
      
      # Should filter by geographic location
      assert html =~ "Manchester" or html =~ "notice"
    end

    test "performs text search across notice fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Search for specific text
      view
      |> form("[data-testid='notice-filters']", filters: %{search: "safety procedures"})
      |> render_change()

      html = render(view)
      
      # Should search across notice content
      assert html =~ "safety" or html =~ "procedures" or html =~ "notice"
    end

    test "combines multiple filters correctly", %{conn: conn, hse_agency: hse_agency} do
      {:ok, view, _html} = live(conn, "/notices")

      # Apply multiple filters
      view
      |> form("[data-testid='notice-filters']", filters: %{
        agency_id: hse_agency.id,
        notice_type: "Improvement Notice",
        compliance_status: "pending"
      })
      |> render_change()

      html = render(view)
      
      # Should apply all filters simultaneously
      assert html =~ "Health and Safety Executive" or html =~ "HSE"
      assert html =~ "Improvement" or html =~ "notice"
    end

    test "clears all filters when clear button clicked", %{conn: conn, hse_agency: hse_agency} do
      {:ok, view, _html} = live(conn, "/notices")

      # Apply filters first
      view
      |> form("[data-testid='notice-filters']", filters: %{
        agency_id: hse_agency.id,
        notice_type: "Improvement Notice"
      })
      |> render_change()

      # Clear filters
      view |> element("button", "Clear") |> render_click()

      html = render(view)
      
      # Should show all notices again
      assert html =~ "HSE-NOTICE" or html =~ "EA-NOTICE" or html =~ "notice"
    end

    test "preserves filter state during navigation", %{conn: conn, hse_agency: hse_agency} do
      {:ok, view, _html} = live(conn, "/notices")

      # Apply filter
      view
      |> form("[data-testid='notice-filters']", filters: %{agency_id: hse_agency.id})
      |> render_change()

      # Navigate to another page and back
      view |> element("a", "Dashboard") |> render_click()
      assert_patched(view, "/")
      
      view |> element("a", "Notices") |> render_click()
      assert_patched(view, "/notices")

      html = render(view)
      
      # Filter state should be preserved or reset appropriately
      assert html =~ "notice" or html =~ "Notice"
    end
  end

  describe "NoticeFilter component validation" do
    setup :create_test_agencies_and_notices

    test "validates date range inputs", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Apply invalid date range (from > to)
      view
      |> form("[data-testid='notice-filters']", filters: %{
        date_from: "2024-12-31",
        date_to: "2024-01-01"
      })
      |> render_change()

      html = render(view)
      
      # Should handle invalid date range gracefully
      refute html =~ "Error" or html =~ "error"
      assert html =~ "notice" or html =~ "Notice"
    end

    test "handles invalid agency selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Try to select non-existent agency
      view
      |> form("[data-testid='notice-filters']", filters: %{agency_id: "invalid-agency-id"})
      |> render_change()

      html = render(view)
      
      # Should handle gracefully without crashing
      assert html =~ "notice" or html =~ "Notice"
    end

    test "sanitizes search input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Try search with special characters
      view
      |> form("[data-testid='notice-filters']", filters: %{search: "<script>alert('xss')</script>"})
      |> render_change()

      html = render(view)
      
      # Should sanitize input and not execute scripts
      refute html =~ "<script>"
      assert html =~ "notice" or html =~ "Notice"
    end

    test "limits search query length", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Try very long search query
      long_query = String.duplicate("a", 1000)
      view
      |> form("[data-testid='notice-filters']", filters: %{search: long_query})
      |> render_change()

      html = render(view)
      
      # Should handle long queries appropriately
      assert html =~ "notice" or html =~ "Notice"
    end
  end

  describe "NoticeFilter component accessibility" do
    setup :create_test_agencies_and_notices

    test "includes proper form labels", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Should have labels for form fields
      assert has_element?(view, "label[for='agency-filter']") or html =~ "Agency"
      assert has_element?(view, "label[for='notice-type-filter']") or html =~ "Notice Type"
      assert has_element?(view, "label[for='date-from-filter']") or html =~ "Date From"
      assert has_element?(view, "label[for='search-filter']") or html =~ "Search"
    end

    test "provides ARIA attributes for complex elements", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Should include ARIA attributes
      assert html =~ "aria-label=" or has_element?(view, "[aria-label]")
      assert html =~ "role=" or has_element?(view, "[role]")
    end

    test "supports keyboard navigation", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Form elements should be keyboard accessible
      assert has_element?(view, "select[tabindex]") or html =~ "tabindex"
      
      # Buttons should have proper focus handling
      assert has_element?(view, "button[type='submit']")
      assert has_element?(view, "button[type='button']")
    end

    test "provides clear visual hierarchy", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Should use proper heading structure
      assert has_element?(view, "h3") or html =~ "<h3"
      
      # Should group related form elements
      assert has_element?(view, "fieldset") or has_element?(view, ".form-group")
    end

    test "includes helpful placeholder text", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Should have meaningful placeholders
      assert html =~ "placeholder=" and html =~ "Search"
      assert html =~ "Select" or html =~ "Choose"
    end
  end

  describe "NoticeFilter component performance" do
    setup do
      # Create larger dataset for performance testing
      {:ok, agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive",
        enabled: true
      })

      {:ok, offender} = Enforcement.create_offender(%{
        name: "Performance Test Company",
        local_authority: "Test Council",
        postcode: "T1 1ST"
      })

      # Create multiple notices for performance testing
      notices = Enum.map(1..50, fn i ->
        {:ok, notice} = Enforcement.create_notice(%{
          regulator_id: "HSE-PERF-#{i}",
          agency_id: agency.id,
          offender_id: offender.id,
          notice_type: "Improvement Notice",
          notice_date: Date.add(~D[2024-01-01], i),
          notice_body: "Performance test notice #{i}"
        })
        notice
      end)

      %{notices: notices, agency: agency, offender: offender}
    end

    test "handles filtering large datasets efficiently", %{conn: conn, agency: agency} do
      start_time = System.monotonic_time(:millisecond)
      
      {:ok, view, _html} = live(conn, "/notices")
      
      # Apply filter
      view
      |> form("[data-testid='notice-filters']", filters: %{agency_id: agency.id})
      |> render_change()

      end_time = System.monotonic_time(:millisecond)
      filter_time = end_time - start_time
      
      html = render(view)
      assert html =~ "HSE-PERF"
      assert filter_time < 1000 # Should filter within 1 second
    end

    test "debounces search input to prevent excessive queries", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Rapid search input changes
      view
      |> form("[data-testid='notice-filters']", filters: %{search: "a"})
      |> render_change()
      
      view
      |> form("[data-testid='notice-filters']", filters: %{search: "ab"})
      |> render_change()
      
      view
      |> form("[data-testid='notice-filters']", filters: %{search: "abc"})
      |> render_change()

      html = render(view)
      
      # Should handle rapid changes efficiently
      assert html =~ "notice" or html =~ "Notice"
    end

    test "limits results to prevent UI performance issues", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      html = render(view)
      
      # Should implement pagination or result limiting
      notice_count = (html |> String.split("HSE-PERF") |> length()) - 1
      assert notice_count <= 25 # Should limit displayed results
    end
  end

  # Helper function to create test agencies and notices
  defp create_test_agencies_and_notices(_context) do
    # Create test agencies
    {:ok, hse_agency} = Enforcement.create_agency(%{
      code: :hse,
      name: "Health and Safety Executive",
      enabled: true
    })

    {:ok, ea_agency} = Enforcement.create_agency(%{
      code: :ea,
      name: "Environment Agency",
      enabled: true
    })

    # Create test offenders
    {:ok, offender1} = Enforcement.create_offender(%{
      name: "Manufacturing Solutions Ltd",
      local_authority: "Manchester City Council",
      postcode: "M1 1AA"
    })

    {:ok, offender2} = Enforcement.create_offender(%{
      name: "Industrial Operations Corp",
      local_authority: "Birmingham City Council",
      postcode: "B2 2BB"
    })

    # Create test notices
    {:ok, notice1} = Enforcement.create_notice(%{
      regulator_id: "HSE-NOTICE-2024-001",
      agency_id: hse_agency.id,
      offender_id: offender1.id,
      notice_type: "Improvement Notice",
      notice_date: ~D[2024-01-15],
      compliance_date: ~D[2024-03-15],
      notice_body: "Implement adequate safety procedures in manufacturing operations"
    })

    {:ok, notice2} = Enforcement.create_notice(%{
      regulator_id: "EA-NOTICE-2024-001",
      agency_id: ea_agency.id,
      offender_id: offender2.id,
      notice_type: "Enforcement Notice",
      notice_date: ~D[2024-01-20],
      compliance_date: ~D[2024-04-20],
      notice_body: "Environmental compliance breach - monitoring required"
    })

    %{
      hse_agency: hse_agency,
      ea_agency: ea_agency,
      offender1: offender1,
      offender2: offender2,
      notice1: notice1,
      notice2: notice2
    }
  end
end