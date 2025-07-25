defmodule EhsEnforcementWeb.Components.EnforcementTimelineTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest

  alias EhsEnforcement.Enforcement
  alias EhsEnforcementWeb.Components.EnforcementTimeline

  describe "EnforcementTimeline component" do
    setup do
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

      # Create test offender
      {:ok, offender} = Enforcement.create_offender(%{
        name: "Timeline Test Corp",
        local_authority: "Manchester City Council",
        industry: "Manufacturing",
        total_cases: 4,
        total_notices: 5,
        total_fines: Decimal.new("285000")
      })

      base_date = ~D[2024-01-15]

      # Create timeline entries spanning multiple years
      {:ok, recent_case} = Enforcement.create_case(%{
        regulator_id: "HSE-2024-001",
        agency_id: hse_agency.id,
        offender_id: offender.id,
        offence_action_date: base_date,
        offence_fine: Decimal.new("85000"),
        offence_breaches: "Health and Safety at Work Act 1974 - Section 2(1)",
        last_synced_at: DateTime.utc_now()
      })

      {:ok, major_case} = Enforcement.create_case(%{
        regulator_id: "HSE-2023-045",
        agency_id: hse_agency.id,
        offender_id: offender.id,
        offence_action_date: Date.add(base_date, -180),
        offence_fine: Decimal.new("125000"),
        offence_breaches: "Management of Health and Safety at Work Regulations 1999",
        last_synced_at: DateTime.utc_now()
      })

      {:ok, env_case} = Enforcement.create_case(%{
        regulator_id: "EA-2022-089",
        agency_id: ea_agency.id,
        offender_id: offender.id,
        offence_action_date: Date.add(base_date, -730),
        offence_fine: Decimal.new("75000"),
        offence_breaches: "Environmental Protection Act 1990 - Section 33(1)(a)",
        last_synced_at: DateTime.utc_now()
      })

      {:ok, improvement_notice} = Enforcement.create_notice(%{
        regulator_id: "HSE-N-2024-001",
        agency_id: hse_agency.id,
        offender_id: offender.id,
        notice_type: "improvement_notice",
        notice_date: Date.add(base_date, -30),
        operative_date: Date.add(base_date, -23),
        compliance_date: Date.add(base_date, 7),
        notice_body: "Improve safety procedures for machinery operation"
      })

      {:ok, prohibition_notice} = Enforcement.create_notice(%{
        regulator_id: "HSE-N-2023-078",
        agency_id: hse_agency.id,
        offender_id: offender.id,
        notice_type: "prohibition_notice",
        notice_date: Date.add(base_date, -365),
        operative_date: Date.add(base_date, -365),
        compliance_date: Date.add(base_date, -335),
        notice_body: "Immediate cessation of unsafe welding operations"
      })

      # Load cases and notices with related data
      cases = Enforcement.list_cases!(
        filter: [offender_id: offender.id],
        load: [:agency, :offender],
        sort: [offence_action_date: :desc]
      )

      notices = Enforcement.list_notices!(
        filter: [offender_id: offender.id],
        load: [:agency, :offender],
        sort: [notice_date: :desc]
      )

      %{
        hse_agency: hse_agency,
        ea_agency: ea_agency,
        offender: offender,
        cases: cases,
        notices: notices,
        recent_case: recent_case,
        major_case: major_case,
        env_case: env_case,
        improvement_notice: improvement_notice,
        prohibition_notice: prohibition_notice
      }
    end

    test "renders timeline structure with proper HTML", %{cases: cases, notices: notices} do
      html = render_component(EnforcementTimeline, %{
        cases: cases,
        notices: notices
      })

      # Should have timeline container
      assert html =~ ~r/<div[^>]*class="[^"]*timeline[^"]*"/
      assert html =~ ~r/data-role="timeline"/
      
      # Should have timeline items
      assert html =~ ~r/data-role="timeline-item"/
      assert html =~ ~r/timeline-entry/
    end

    test "displays entries in chronological order (most recent first)", %{cases: cases, notices: notices, recent_case: recent_case, env_case: env_case} do
      html = render_component(EnforcementTimeline, %{
        cases: cases,
        notices: notices
      })

      # Find positions of regulator IDs in HTML
      recent_pos = :binary.match(html, recent_case.regulator_id) |> elem(0)
      env_pos = :binary.match(html, env_case.regulator_id) |> elem(0)
      
      # Recent case (2024) should appear before environmental case (2022)
      assert recent_pos < env_pos
    end

    test "groups entries by year with proper headers", %{cases: cases, notices: notices} do
      html = render_component(EnforcementTimeline, %{
        cases: cases,
        notices: notices
      })

      # Should have year group headers
      assert html =~ ~r/<h[2-4][^>]*>2024<\/h[2-4]>/
      assert html =~ ~r/<h[2-4][^>]*>2023<\/h[2-4]>/
      assert html =~ ~r/<h[2-4][^>]*>2022<\/h[2-4]>/
      
      # Should have year grouping containers
      assert html =~ ~r/data-year="2024"/
      assert html =~ ~r/data-year="2023"/
      assert html =~ ~r/data-year="2022"/
    end

    test "displays case information with proper formatting", %{cases: cases, notices: notices, recent_case: recent_case} do
      html = render_component(EnforcementTimeline, %{
        cases: cases,
        notices: notices
      })

      # Should show case details
      assert html =~ recent_case.regulator_id
      assert html =~ "£85,000" # formatted fine amount
      assert html =~ "Health and Safety at Work Act 1974"
      assert html =~ "Section 2(1)"
      
      # Should have case-specific styling
      assert html =~ ~r/data-type="case"/
      assert html =~ ~r/timeline-case/
    end

    test "displays notice information with proper formatting", %{cases: cases, notices: notices, improvement_notice: improvement_notice} do
      html = render_component(EnforcementTimeline, %{
        cases: cases,
        notices: notices
      })

      # Should show notice details
      assert html =~ improvement_notice.regulator_id
      assert html =~ "Improvement Notice"
      assert html =~ "Improve safety procedures for machinery operation"
      
      # Should show compliance information
      assert html =~ "Compliance Date"
      assert html =~ "30 days" # compliance period calculation
      
      # Should have notice-specific styling
      assert html =~ ~r/data-type="notice"/
      assert html =~ ~r/timeline-notice/
    end

    test "shows agency information for each entry", %{cases: cases, notices: notices} do
      html = render_component(EnforcementTimeline, %{
        cases: cases,
        notices: notices
      })

      # Should show agency names
      assert html =~ "Health and Safety Executive"
      assert html =~ "Environment Agency"
      
      # Should have agency-specific styling
      assert html =~ ~r/data-agency="hse"/
      assert html =~ ~r/data-agency="ea"/
    end

    test "applies different styling for different notice types", %{cases: cases, notices: notices} do
      html = render_component(EnforcementTimeline, %{
        cases: cases,
        notices: notices
      })

      # Should differentiate notice types
      assert html =~ ~r/data-notice-type="improvement_notice"/
      assert html =~ ~r/data-notice-type="prohibition_notice"/
      
      # Should have type-specific classes
      assert html =~ ~r/notice-improvement|improvement-notice/
      assert html =~ ~r/notice-prohibition|prohibition-notice/
    end

    test "displays enforcement severity indicators", %{cases: cases, notices: notices, major_case: major_case} do
      html = render_component(EnforcementTimeline, %{
        cases: cases,
        notices: notices
      })

      # Should indicate high-value cases
      assert html =~ ~r/data-severity="high"/ # For £125k case
      assert html =~ ~r/severity-high|high-fine/
      
      # Should show severity colors/indicators
      assert html =~ ~r/bg-red|text-red|border-red/ # High severity styling
    end

    test "shows compliance status for notices", %{cases: cases, notices: notices} do
      html = render_component(EnforcementTimeline, %{
        cases: cases,
        notices: notices
      })

      # Should show compliance status
      assert html =~ "Complied" || html =~ "Overdue" || html =~ "Pending"
      assert html =~ ~r/compliance-status/
      
      # Should have status-specific styling
      assert html =~ ~r/status-complied|status-overdue|status-pending/
    end

    test "includes timeline visual elements", %{cases: cases, notices: notices} do
      html = render_component(EnforcementTimeline, %{
        cases: cases,
        notices: notices
      })

      # Should have visual timeline elements
      assert html =~ ~r/timeline-line|timeline-connector/
      assert html =~ ~r/timeline-dot|timeline-marker/
      
      # Should have proper visual structure
      assert html =~ ~r/border-l|border-gray/ # Vertical line
    end

    test "supports filtering by entry type", %{cases: cases, notices: notices} do
      # Test cases only
      cases_html = render_component(EnforcementTimeline, %{
        cases: cases,
        notices: [],
        filter_type: "cases"
      })
      
      assert cases_html =~ "HSE-2024-001" # Case ID
      refute cases_html =~ "HSE-N-2024-001" # Notice ID

      # Test notices only  
      notices_html = render_component(EnforcementTimeline, %{
        cases: [],
        notices: notices,
        filter_type: "notices"
      })
      
      assert notices_html =~ "HSE-N-2024-001" # Notice ID
      refute notices_html =~ "HSE-2024-001" # Case ID
    end

    test "supports filtering by agency", %{cases: cases, notices: notices} do
      html = render_component(EnforcementTimeline, %{
        cases: cases,
        notices: notices,
        filter_agency: "hse"
      })

      # Should show HSE entries
      assert html =~ "HSE-2024-001"
      assert html =~ "HSE-2023-045"
      
      # Should not show EA entries when filtered
      refute html =~ "EA-2022-089"
    end

    test "supports date range filtering", %{cases: cases, notices: notices} do
      html = render_component(EnforcementTimeline, %{
        cases: cases,
        notices: notices,
        from_date: ~D[2024-01-01],
        to_date: ~D[2024-12-31]
      })

      # Should show 2024 entries
      assert html =~ "HSE-2024-001"
      assert html =~ "2024"
      
      # Should not show older entries
      refute html =~ "EA-2022-089"
    end

    test "handles empty timeline gracefully", %{} do
      html = render_component(EnforcementTimeline, %{
        cases: [],
        notices: []
      })

      # Should show empty state
      assert html =~ "No enforcement history"
      assert html =~ "No cases or notices found"
      assert html =~ ~r/empty-timeline|no-data/
    end

    test "includes accessibility attributes", %{cases: cases, notices: notices} do
      html = render_component(EnforcementTimeline, %{
        cases: cases,
        notices: notices
      })

      # Should have proper ARIA attributes
      assert html =~ ~r/role="list"/ # Timeline as list
      assert html =~ ~r/role="listitem"/ # Timeline items
      assert html =~ ~r/aria-label="[^"]*timeline[^"]*"/
      
      # Should have semantic structure
      assert html =~ ~r/<time[^>]*datetime/
    end

    test "supports keyboard navigation", %{cases: cases, notices: notices} do
      html = render_component(EnforcementTimeline, %{
        cases: cases,
        notices: notices
      })

      # Timeline items should be focusable
      assert html =~ ~r/tabindex="0"/
      assert html =~ ~r/focusable|keyboard-nav/
    end

    test "displays loading state", %{} do
      html = render_component(EnforcementTimeline, %{
        cases: [],
        notices: [],
        loading: true
      })

      # Should show loading indicator
      assert html =~ "Loading timeline"
      assert html =~ ~r/loading|spinner|skeleton/
    end

    test "shows detailed case breach information", %{cases: cases, notices: notices, recent_case: recent_case} do
      html = render_component(EnforcementTimeline, %{
        cases: cases,
        notices: notices,
        show_details: true
      })

      # Should show full breach details
      assert html =~ "Health and Safety at Work Act 1974 - Section 2(1)"
      assert html =~ ~r/breach-details|violation-text/
      
      # Should be expandable/collapsible
      assert html =~ ~r/expandable|collapsible|toggle/
    end

    test "displays enforcement patterns and trends", %{cases: cases, notices: notices} do
      html = render_component(EnforcementTimeline, %{
        cases: cases,
        notices: notices,
        show_patterns: true
      })

      # Should show pattern indicators
      assert html =~ "Escalating fines" || html =~ "Repeated violations"
      assert html =~ ~r/pattern-indicator|trend-marker/
      
      # Should show enforcement frequency
      assert html =~ "Multiple agencies involved"
    end

    test "handles very long timeline with pagination", %{offender: offender, hse_agency: hse_agency} do
      # Create many additional entries
      for i <- 1..50 do
        {:ok, _case} = Enforcement.create_case(%{
          regulator_id: "HSE-BULK-#{i}",
          agency_id: hse_agency.id,
          offender_id: offender.id,
          offence_action_date: Date.add(~D[2024-01-01], -i),
          offence_fine: Decimal.new("#{i * 1000}"),
          offence_breaches: "Bulk test case #{i}",
          last_synced_at: DateTime.utc_now()
        })
      end

      all_cases = Enforcement.list_cases!(
        filter: [offender_id: offender.id],
        load: [:agency],
        sort: [offence_action_date: :desc]
      )

      html = render_component(EnforcementTimeline, %{
        cases: all_cases,
        notices: [],
        page_size: 10
      })

      # Should limit initial display
      timeline_items = html |> Floki.find("[data-role='timeline-item']")
      assert length(timeline_items) <= 10
      
      # Should have load more functionality
      assert html =~ "Load more" || html =~ "Show more"
      assert html =~ ~r/load-more|pagination/
    end
  end

  describe "EnforcementTimeline component responsive design" do
    setup do
      {:ok, hse_agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive",
        enabled: true
      })

      {:ok, offender} = Enforcement.create_offender(%{
        name: "Responsive Corp",
        total_cases: 2,
        total_notices: 1,
        total_fines: Decimal.new("50000")
      })

      {:ok, case1} = Enforcement.create_case(%{
        regulator_id: "HSE-RESP-001",
        agency_id: hse_agency.id,
        offender_id: offender.id,
        offence_action_date: ~D[2024-01-15],
        offence_fine: Decimal.new("25000"),
        offence_breaches: "Test violation",
        last_synced_at: DateTime.utc_now()
      })

      cases = [case1]
      %{cases: cases, notices: []}
    end

    test "adapts layout for mobile screens", %{cases: cases, notices: notices} do
      html = render_component(EnforcementTimeline, %{
        cases: cases,
        notices: notices,
        mobile_layout: true
      })

      # Should have mobile-friendly classes
      assert html =~ ~r/mobile|responsive|sm:|md:/
      assert html =~ ~r/timeline-mobile/
    end

    test "stacks timeline items vertically on small screens", %{cases: cases, notices: notices} do
      html = render_component(EnforcementTimeline, %{
        cases: cases,
        notices: notices
      })

      # Should use vertical stacking
      assert html =~ ~r/flex-col|stack-vertical/
      assert html =~ ~r/sm:flex-row/ # Horizontal on larger screens
    end

    test "adjusts timeline visual elements for mobile", %{cases: cases, notices: notices} do
      html = render_component(EnforcementTimeline, %{
        cases: cases,
        notices: notices
      })

      # Should adapt timeline line for mobile
      assert html =~ ~r/timeline-mobile|mobile-timeline/
      assert html =~ ~r/border-l.*sm:border-t/ # Vertical on mobile, horizontal on desktop
    end
  end
end