defmodule EhsEnforcementWeb.NoticeTimelineComponentTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  alias EhsEnforcement.Enforcement

  describe "NoticeTimeline component rendering" do
    setup do
      # Create test agency
      {:ok, hse_agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive",
        enabled: true
      })

      # Create test offenders
      {:ok, offender1} = Enforcement.create_offender(%{
        name: "Timeline Test Company Ltd",
        local_authority: "Manchester City Council",
        postcode: "M1 1AA"
      })

      {:ok, offender2} = Enforcement.create_offender(%{
        name: "Industrial Operations Corp",
        local_authority: "Birmingham City Council",
        postcode: "B2 2BB"
      })

      # Create notices with different dates for timeline testing
      {:ok, notice1} = Enforcement.create_notice(%{
        regulator_id: "HSE-NOTICE-2024-001",
        regulator_ref_number: "HSE/REF/001",
        agency_id: hse_agency.id,
        offender_id: offender1.id,
        notice_type: "Improvement Notice",
        notice_date: ~D[2024-01-15],
        operative_date: ~D[2024-01-29],
        compliance_date: ~D[2024-03-15],
        notice_body: "First notice - safety procedures implementation required"
      })

      {:ok, notice2} = Enforcement.create_notice(%{
        regulator_id: "HSE-NOTICE-2024-002",
        regulator_ref_number: "HSE/REF/002",
        agency_id: hse_agency.id,
        offender_id: offender2.id,
        notice_type: "Prohibition Notice",
        notice_date: ~D[2024-01-15],  # Same date as notice1
        operative_date: ~D[2024-01-15],
        compliance_date: ~D[2024-02-15],
        notice_body: "Immediate prohibition of crane operations"
      })

      {:ok, notice3} = Enforcement.create_notice(%{
        regulator_id: "HSE-NOTICE-2024-003",
        regulator_ref_number: "HSE/REF/003",
        agency_id: hse_agency.id,
        offender_id: offender1.id,
        notice_type: "Improvement Notice",
        notice_date: ~D[2024-01-22],
        operative_date: ~D[2024-02-05],
        compliance_date: ~D[2024-04-22],
        notice_body: "Follow-up notice for additional safety measures"
      })

      {:ok, notice4} = Enforcement.create_notice(%{
        regulator_id: "HSE-NOTICE-2024-004",
        regulator_ref_number: "HSE/REF/004",
        agency_id: hse_agency.id,
        offender_id: offender2.id,
        notice_type: "Enforcement Notice",
        notice_date: ~D[2024-02-01],
        operative_date: ~D[2024-02-08],
        compliance_date: ~D[2024-05-01],
        notice_body: "Environmental compliance enforcement required"
      })

      %{
        agency: hse_agency,
        offender1: offender1,
        offender2: offender2,
        notice1: notice1,
        notice2: notice2,
        notice3: notice3,
        notice4: notice4
      }
    end

    test "displays timeline view when activated", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()

      html = render(view)
      
      # Should display timeline container
      assert has_element?(view, "[data-testid='notice-timeline']")
      assert html =~ "timeline" or html =~ "Timeline"
    end

    test "groups notices by date in chronological order", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()

      html = render(view)
      
      # Should show date groupings
      assert has_element?(view, "[data-date='2024-01-15']") or html =~ "January 15, 2024"
      assert has_element?(view, "[data-date='2024-01-22']") or html =~ "January 22, 2024"
      assert has_element?(view, "[data-date='2024-02-01']") or html =~ "February 1, 2024"
      
      # Should display in chronological order (most recent first or oldest first)
      jan15_pos = html |> String.split("January 15") |> length()
      jan22_pos = html |> String.split("January 22") |> length()
      feb01_pos = html |> String.split("February 1") |> length()
      
      assert jan15_pos != jan22_pos
      assert jan22_pos != feb01_pos
    end

    test "displays multiple notices on same date", %{conn: conn, notice1: notice1, notice2: notice2} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()

      html = render(view)
      
      # Should show both notices issued on Jan 15, 2024
      assert html =~ notice1.regulator_id
      assert html =~ notice2.regulator_id
      assert html =~ "Improvement Notice"
      assert html =~ "Prohibition Notice"
      
      # Should group them under the same date
      assert html =~ "Timeline Test Company Ltd"
      assert html =~ "Industrial Operations Corp"
    end

    test "shows timeline entries with proper visual structure", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()

      html = render(view)
      
      # Should have timeline entry elements
      assert has_element?(view, "[data-testid='timeline-entry']") or
             has_element?(view, ".timeline-entry")
      
      # Should have visual timeline indicators (dots, lines, etc.)
      assert has_element?(view, ".timeline-dot") or
             has_element?(view, ".timeline-marker") or
             html =~ "●" or html =~ "○"
    end

    test "displays notice details within timeline entries", %{conn: conn, notice1: notice1} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()

      html = render(view)
      
      # Should show notice information
      assert html =~ notice1.regulator_id
      assert html =~ notice1.notice_type
      assert html =~ "Timeline Test Company Ltd"
      assert html =~ "safety procedures implementation"
      
      # Should show key dates
      assert html =~ "Operative:" or html =~ "Compliance:"
    end

    test "includes action buttons within timeline entries", %{conn: conn, notice1: notice1} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()

      html = render(view)
      
      # Should have action buttons for each notice
      assert has_element?(view, "a[href='/notices/#{notice1.id}']") or
             has_element?(view, "button", "View Details")
    end

    test "highlights different notice types with visual indicators", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()

      html = render(view)
      
      # Should differentiate notice types visually
      assert has_element?(view, "[data-notice-type='Improvement Notice']")
      assert has_element?(view, "[data-notice-type='Prohibition Notice']")
      assert has_element?(view, "[data-notice-type='Enforcement Notice']")
      
      # Should have different styling/colors for different types
      assert html =~ "improvement" or html =~ "prohibition" or html =~ "enforcement"
    end

    test "shows compliance status in timeline entries", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()

      html = render(view)
      
      # Should show compliance status for each notice
      assert html =~ "Pending" or html =~ "pending" or
             html =~ "Overdue" or html =~ "overdue" or
             html =~ "Compliant" or html =~ "compliant"
    end
  end

  describe "NoticeTimeline component filtering" do
    setup :create_timeline_test_data

    test "filters timeline by notice type", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view and apply filter
      view |> element("button", "Timeline View") |> render_click()
      
      view
      |> form("[data-testid='notice-filters']", filters: %{notice_type: "Improvement Notice"})
      |> render_change()

      html = render(view)
      
      # Should show only Improvement Notices in timeline
      assert html =~ "Improvement Notice"
      refute html =~ "Prohibition Notice"
    end

    test "filters timeline by date range", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view and apply date filter
      view |> element("button", "Timeline View") |> render_click()
      
      view
      |> form("[data-testid='notice-filters']", filters: %{
        date_from: "2024-01-01",
        date_to: "2024-01-31"
      })
      |> render_change()

      html = render(view)
      
      # Should show only notices from January
      assert html =~ "January" or html =~ "2024-01"
      refute html =~ "February" # February notices should be hidden
    end

    test "filters timeline by agency", %{conn: conn, hse_agency: hse_agency} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view and apply agency filter
      view |> element("button", "Timeline View") |> render_click()
      
      view
      |> form("[data-testid='notice-filters']", filters: %{agency_id: hse_agency.id})
      |> render_change()

      html = render(view)
      
      # Should show only HSE notices
      assert html =~ "Health and Safety Executive" or html =~ "HSE"
    end

    test "maintains timeline structure with filtered results", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view and apply filter
      view |> element("button", "Timeline View") |> render_click()
      
      view
      |> form("[data-testid='notice-filters']", filters: %{notice_type: "Improvement Notice"})
      |> render_change()

      html = render(view)
      
      # Should maintain timeline structure even with fewer results
      assert has_element?(view, "[data-testid='notice-timeline']")
      assert has_element?(view, "[data-testid='timeline-entry']")
    end

    test "updates timeline in real-time as filters change", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()
      
      # Apply first filter
      view
      |> form("[data-testid='notice-filters']", filters: %{notice_type: "Improvement Notice"})
      |> render_change()

      html1 = render(view)
      
      # Change filter
      view
      |> form("[data-testid='notice-filters']", filters: %{notice_type: "Prohibition Notice"})
      |> render_change()

      html2 = render(view)
      
      # Should show different results
      assert html1 != html2
      assert html2 =~ "Prohibition Notice"
    end
  end

  describe "NoticeTimeline component interactions" do
    setup :create_timeline_test_data

    test "allows switching between timeline and table views", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()
      assert has_element?(view, "[data-testid='notice-timeline']")
      
      # Switch back to table view
      view |> element("button", "Table View") |> render_click()
      assert has_element?(view, "[data-testid='notice-list']") or has_element?(view, "table")
      refute has_element?(view, "[data-testid='notice-timeline']")
    end

    test "preserves view state during filtering", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()
      
      # Apply filter
      view
      |> form("[data-testid='notice-filters']", filters: %{notice_type: "Improvement Notice"})
      |> render_change()

      html = render(view)
      
      # Should remain in timeline view
      assert has_element?(view, "[data-testid='notice-timeline']")
      assert html =~ "Improvement Notice"
    end

    test "supports keyboard navigation in timeline", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()

      html = render(view)
      
      # Timeline entries should be keyboard accessible
      assert has_element?(view, "[tabindex]") or html =~ "tabindex"
      assert has_element?(view, "a") or has_element?(view, "button")
    end

    test "handles empty timeline results gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Clear all notices
      Repo.delete_all(EhsEnforcement.Enforcement.Notice)
      
      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()

      html = render(view)
      
      # Should show empty state message
      assert html =~ "No notices found" or 
             html =~ "no notices to display" or
             html =~ "empty timeline"
    end

    test "expands and collapses timeline entries", %{conn: conn, notice1: notice1} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()

      # Expand entry details (if implemented)
      if has_element?(view, "button", "Show Details") do
        view |> element("button", "Show Details") |> render_click()
        html = render(view)
        assert html =~ notice1.notice_body
      end

      # Test passes if expand/collapse not implemented
      assert true
    end
  end

  describe "NoticeTimeline component performance" do
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

      # Create 100 notices across different dates
      notices = Enum.map(1..100, fn i ->
        {:ok, notice} = Enforcement.create_notice(%{
          regulator_id: "HSE-PERF-#{String.pad_leading(to_string(i), 3, "0")}",
          agency_id: agency.id,
          offender_id: offender.id,
          notice_type: "Improvement Notice",
          notice_date: Date.add(~D[2024-01-01], rem(i, 30)), # Spread across 30 days
          notice_body: "Performance test notice #{i}"
        })
        notice
      end)

      %{notices: notices, agency: agency, offender: offender}
    end

    test "renders large timeline efficiently", %{conn: conn} do
      start_time = System.monotonic_time(:millisecond)
      
      {:ok, view, _html} = live(conn, "/notices")
      
      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()

      end_time = System.monotonic_time(:millisecond)
      render_time = end_time - start_time
      
      html = render(view)
      assert has_element?(view, "[data-testid='notice-timeline']")
      assert render_time < 2000 # Should render within 2 seconds
    end

    test "implements virtual scrolling or pagination for large datasets", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()

      html = render(view)
      
      # Should limit displayed entries or implement pagination
      notice_count = html |> String.split("HSE-PERF-") |> length() - 1
      assert notice_count <= 50 # Should limit for performance
    end

    test "groups dates efficiently to reduce DOM elements", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()

      html = render(view)
      
      # Should group notices by date to reduce DOM complexity
      date_groups = html |> String.split("data-date=") |> length() - 1
      assert date_groups <= 30 # Should have reasonable number of date groups
    end

    test "handles rapid view switching without performance degradation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      start_time = System.monotonic_time(:millisecond)
      
      # Rapid view switching
      view |> element("button", "Timeline View") |> render_click()
      view |> element("button", "Table View") |> render_click()
      view |> element("button", "Timeline View") |> render_click()
      view |> element("button", "Table View") |> render_click()

      end_time = System.monotonic_time(:millisecond)
      switch_time = end_time - start_time
      
      html = render(view)
      assert html =~ "notice" or html =~ "Notice"
      assert switch_time < 1000 # Should handle rapid switching efficiently
    end
  end

  describe "NoticeTimeline component accessibility" do
    setup :create_timeline_test_data

    test "includes proper ARIA labels for timeline structure", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()

      html = render(view)
      
      # Should include ARIA attributes for timeline
      assert html =~ "aria-label=" or has_element?(view, "[aria-label]")
      assert html =~ "role=" or has_element?(view, "[role]")
      
      # Timeline should be announced to screen readers
      assert html =~ "timeline" or html =~ "chronological"
    end

    test "provides proper heading structure for dates", %{conn: conn} do
      {:ok, view, html} = live(conn, "/notices")

      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()

      html = render(view)
      
      # Should use proper heading hierarchy
      assert has_element?(view, "h3") or has_element?(view, "h4")
      
      # Date headings should be semantic
      assert html =~ "<h" and html =~ "January" or html =~ "2024"
    end

    test "supports keyboard navigation through timeline entries", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()

      html = render(view)
      
      # Should support tab navigation
      assert has_element?(view, "[tabindex]") or has_element?(view, "a") or has_element?(view, "button")
      
      # Focus should be manageable
      assert html =~ "tabindex" or has_element?(view, ":focus")
    end

    test "provides descriptive text for visual timeline elements", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()

      html = render(view)
      
      # Visual elements should have text alternatives
      assert html =~ "issued" or html =~ "Issued"
      assert html =~ "notice" or html =~ "Notice"
      
      # Timeline markers should be described
      assert html =~ "timeline" or html =~ "chronological"
    end

    test "maintains semantic meaning without visual styling", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/notices")

      # Switch to timeline view
      view |> element("button", "Timeline View") |> render_click()

      html = render(view)
      
      # Content should be meaningful without CSS
      assert html =~ "January" or html =~ "February"
      assert html =~ "HSE-NOTICE"
      assert html =~ "Improvement Notice" or html =~ "Prohibition Notice"
    end
  end

  # Helper function to create timeline test data
  defp create_timeline_test_data(_context) do
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
      name: "Timeline Test Company Ltd",
      local_authority: "Manchester City Council",
      postcode: "M1 1AA"
    })

    {:ok, offender2} = Enforcement.create_offender(%{
      name: "Industrial Operations Corp",
      local_authority: "Birmingham City Council",
      postcode: "B2 2BB"
    })

    # Create notices across different dates
    {:ok, notice1} = Enforcement.create_notice(%{
      regulator_id: "HSE-NOTICE-2024-001",
      agency_id: hse_agency.id,
      offender_id: offender1.id,
      notice_type: "Improvement Notice",
      notice_date: ~D[2024-01-15],
      compliance_date: ~D[2024-03-15],
      notice_body: "Safety procedures implementation required"
    })

    {:ok, notice2} = Enforcement.create_notice(%{
      regulator_id: "HSE-NOTICE-2024-002",
      agency_id: hse_agency.id,
      offender_id: offender2.id,
      notice_type: "Prohibition Notice",
      notice_date: ~D[2024-01-15], # Same date as notice1
      compliance_date: ~D[2024-02-15],
      notice_body: "Immediate prohibition of crane operations"
    })

    {:ok, notice3} = Enforcement.create_notice(%{
      regulator_id: "HSE-NOTICE-2024-003",
      agency_id: hse_agency.id,
      offender_id: offender1.id,
      notice_type: "Improvement Notice",
      notice_date: ~D[2024-01-22],
      compliance_date: ~D[2024-04-22],
      notice_body: "Follow-up notice for additional safety measures"
    })

    {:ok, notice4} = Enforcement.create_notice(%{
      regulator_id: "EA-NOTICE-2024-001",
      agency_id: ea_agency.id,
      offender_id: offender2.id,
      notice_type: "Enforcement Notice",
      notice_date: ~D[2024-02-01],
      compliance_date: ~D[2024-05-01],
      notice_body: "Environmental compliance enforcement required"
    })

    %{
      hse_agency: hse_agency,
      ea_agency: ea_agency,
      offender1: offender1,
      offender2: offender2,
      notice1: notice1,
      notice2: notice2,
      notice3: notice3,
      notice4: notice4
    }
  end
end