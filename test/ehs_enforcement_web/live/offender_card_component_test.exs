defmodule EhsEnforcementWeb.Components.OffenderCardTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest

  alias EhsEnforcement.Enforcement
  alias EhsEnforcementWeb.Components.OffenderCard

  describe "OffenderCard component" do
    setup do
      {:ok, hse_agency} = Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive",
        enabled: true
      })

      {:ok, repeat_offender} = Enforcement.create_offender(%{
        name: "Repeat Manufacturing Ltd",
        local_authority: "Manchester City Council",
        postcode: "M1 1AA",
        industry: "Manufacturing",
        business_type: :limited_company,
        main_activity: "Metal fabrication and processing",
        total_cases: 6,
        total_notices: 9,
        total_fines: Decimal.new("350000"),
        first_seen_date: ~D[2020-01-15],
        last_seen_date: ~D[2024-02-10]
      })

      {:ok, new_offender} = Enforcement.create_offender(%{
        name: "New Business Ltd",
        local_authority: "Leeds City Council",
        postcode: "LS2 2BB",
        industry: "Retail",
        business_type: :limited_company,
        main_activity: "General retail operations",
        total_cases: 1,
        total_notices: 1,
        total_fines: Decimal.new("12000"),
        first_seen_date: ~D[2023-11-20],
        last_seen_date: ~D[2023-11-20]
      })

      %{
        hse_agency: hse_agency,
        repeat_offender: repeat_offender,
        new_offender: new_offender
      }
    end

    test "renders basic offender information", %{repeat_offender: offender} do
      html = render_component(OffenderCard, %{offender: offender})

      # Should display key offender details
      assert html =~ offender.name
      assert html =~ "Manchester City Council"
      assert html =~ "M1 1AA"
      assert html =~ "Manufacturing"
      assert html =~ "Limited Company"
    end

    test "displays enforcement statistics prominently", %{repeat_offender: offender} do
      html = render_component(OffenderCard, %{offender: offender})

      # Should show enforcement metrics
      assert html =~ "6" # total_cases
      assert html =~ "9" # total_notices  
      assert html =~ "£350,000" # formatted total_fines
      
      # Should have statistics section
      assert html =~ "Cases"
      assert html =~ "Notices"
      assert html =~ "Total Fines"
    end

    test "shows risk level indicator with appropriate styling", %{repeat_offender: repeat_offender, new_offender: new_offender} do
      repeat_html = render_component(OffenderCard, %{offender: repeat_offender})
      
      # High risk offender (6+ cases, £350k+ fines)
      assert repeat_html =~ "High Risk"
      assert repeat_html =~ ~r/risk-high|bg-red|text-red/
      
      new_html = render_component(OffenderCard, %{offender: new_offender})
      
      # Low risk offender (1 case, £12k fines)  
      assert new_html =~ "Low Risk"
      assert new_html =~ ~r/risk-low|bg-green|text-green/
    end

    test "displays repeat offender badge", %{repeat_offender: offender} do
      html = render_component(OffenderCard, %{offender: offender})

      # Should show repeat offender indicator
      assert html =~ "Repeat Offender"
      assert html =~ ~r/data-repeat-offender="true"/
      assert html =~ ~r/badge|tag|label/
    end

    test "shows activity timeline summary", %{repeat_offender: offender} do
      html = render_component(OffenderCard, %{offender: offender})

      # Should show enforcement span
      assert html =~ "2020" # first_seen_date year
      assert html =~ "2024" # last_seen_date year
      assert html =~ "4 years" # calculated span
      
      # Should indicate recent activity
      assert html =~ "Recent Activity" || html =~ "Last seen"
    end

    test "includes clickable area for navigation", %{repeat_offender: offender} do
      html = render_component(OffenderCard, %{offender: offender})

      # Should be clickable/linkable to detail view
      assert html =~ ~r/href="\/offenders\/#{offender.id}"/
      assert html =~ ~r/data-offender-id="#{offender.id}"/
      assert html =~ ~r/cursor-pointer|clickable/
    end

    test "displays main activity information", %{repeat_offender: offender} do
      html = render_component(OffenderCard, %{offender: offender})

      # Should show business activity
      assert html =~ "Metal fabrication and processing"
      assert html =~ "Main Activity" || html =~ "Business Type"
    end

    test "applies appropriate CSS styling", %{repeat_offender: offender} do
      html = render_component(OffenderCard, %{offender: offender})

      # Should have card styling classes
      assert html =~ ~r/card|border|shadow|rounded/
      assert html =~ ~r/offender-card/
      
      # Should have layout classes
      assert html =~ ~r/flex|grid|p-|m-/
    end

    test "shows industry-specific indicators", %{repeat_offender: repeat_offender, new_offender: new_offender} do
      manufacturing_html = render_component(OffenderCard, %{offender: repeat_offender})
      retail_html = render_component(OffenderCard, %{offender: new_offender})

      # Should show industry with appropriate styling
      assert manufacturing_html =~ ~r/data-industry="Manufacturing"/
      assert retail_html =~ ~r/data-industry="Retail"/
      
      # Could have industry-specific icons or colors
      assert manufacturing_html =~ "Manufacturing"
      assert retail_html =~ "Retail"
    end

    test "handles missing optional fields gracefully", %{} do
      {:ok, minimal_offender} = Enforcement.create_offender(%{
        name: "Minimal Corp",
        # Only required fields, no optional ones
        total_cases: 1,
        total_notices: 0,
        total_fines: Decimal.new("5000")
      })

      html = render_component(OffenderCard, %{offender: minimal_offender})

      # Should still render without crashing
      assert html =~ "Minimal Corp"
      assert html =~ "1" # total_cases
      assert html =~ "£5,000" # total_fines
      
      # Should handle nil fields gracefully
      refute html =~ "null"
      refute html =~ "undefined"
    end

    test "supports different card sizes", %{repeat_offender: offender} do
      compact_html = render_component(OffenderCard, %{
        offender: offender, 
        size: :compact
      })
      
      full_html = render_component(OffenderCard, %{
        offender: offender,
        size: :full
      })

      # Should apply size-appropriate classes
      assert compact_html =~ ~r/compact|small|sm/
      assert full_html =~ ~r/full|large|lg/
    end

    test "displays geographic information", %{repeat_offender: offender} do
      html = render_component(OffenderCard, %{offender: offender})

      # Should show location details
      assert html =~ "Manchester City Council"
      assert html =~ "M1 1AA"
      
      # Should have location section
      assert html =~ "Location" || html =~ "Address"
    end

    test "shows enforcement trend indicators", %{repeat_offender: offender} do
      html = render_component(OffenderCard, %{offender: offender})

      # Should indicate enforcement patterns
      assert html =~ ~r/trending|increasing|pattern/
      
      # Should show if activity is recent
      assert html =~ ~r/recent|active|2024/
    end

    test "includes accessibility attributes", %{repeat_offender: offender} do
      html = render_component(OffenderCard, %{offender: offender})

      # Should have proper ARIA attributes
      assert html =~ ~r/aria-label="[^"]*#{Regex.escape(offender.name)}[^"]*"/
      assert html =~ ~r/role="button"|role="link"/
      
      # Should have keyboard navigation support
      assert html =~ ~r/tabindex="0"/
    end

    test "supports hover and focus states", %{repeat_offender: offender} do
      html = render_component(OffenderCard, %{offender: offender})

      # Should have hover/focus styling
      assert html =~ ~r/hover:|focus:|transition/
      assert html =~ ~r/offender-card-interactive/
    end

    test "displays badges for special statuses", %{repeat_offender: offender} do
      html = render_component(OffenderCard, %{offender: offender})

      # Should show various badges/tags
      assert html =~ "High Risk"
      assert html =~ "Repeat Offender"
      
      # Should have badge styling
      assert html =~ ~r/badge|tag|pill/
    end

    test "shows summary statistics in prominent location", %{repeat_offender: offender} do
      html = render_component(OffenderCard, %{offender: offender})

      # Statistics should be prominent
      assert html =~ ~r/<.*class="[^"]*stats[^"]*"[^>]*>/
      assert html =~ ~r/<.*class="[^"]*metric[^"]*"[^>]*>/
      
      # Numbers should be emphasized
      assert html =~ ~r/font-bold|text-lg|emphasis/
    end

    test "handles very long company names gracefully", %{} do
      {:ok, long_name_offender} = Enforcement.create_offender(%{
        name: "Very Long Company Name That Should Be Truncated Manufacturing and Processing Limited Partnership",
        total_cases: 1,
        total_notices: 1,
        total_fines: Decimal.new("10000")
      })

      html = render_component(OffenderCard, %{offender: long_name_offender})

      # Should handle long names (truncation or wrapping)
      assert html =~ "Very Long Company Name"
      assert html =~ ~r/truncate|line-clamp|text-wrap/
    end
  end

  describe "OffenderCard component responsive design" do
    setup do
      {:ok, offender} = Enforcement.create_offender(%{
        name: "Responsive Corp",
        local_authority: "Test Council",
        industry: "Technology",
        total_cases: 2,
        total_notices: 3,
        total_fines: Decimal.new("85000")
      })

      %{offender: offender}
    end

    test "adapts layout for mobile screens", %{offender: offender} do
      html = render_component(OffenderCard, %{
        offender: offender,
        mobile_optimized: true
      })

      # Should have mobile-friendly classes
      assert html =~ ~r/sm:|md:|lg:/ # Tailwind responsive prefixes
      assert html =~ ~r/mobile|responsive/
    end

    test "stacks information vertically on small screens", %{offender: offender} do
      html = render_component(OffenderCard, %{offender: offender})

      # Should use vertical stacking on mobile
      assert html =~ ~r/flex-col|stack|vertical/
      assert html =~ ~r/sm:flex-row|md:grid/ # Horizontal on larger screens
    end

    test "adjusts text sizes for readability", %{offender: offender} do
      html = render_component(OffenderCard, %{offender: offender})

      # Should have responsive text sizing
      assert html =~ ~r/text-sm|text-base|sm:text-lg/
      assert html =~ ~r/responsive-text/
    end
  end

  describe "OffenderCard component theming" do
    setup do
      {:ok, offender} = Enforcement.create_offender(%{
        name: "Themed Corp",
        industry: "Construction",
        total_cases: 3,
        total_notices: 2,
        total_fines: Decimal.new("95000")
      })

      %{offender: offender}
    end

    test "supports dark mode styling", %{offender: offender} do
      html = render_component(OffenderCard, %{
        offender: offender,
        theme: :dark
      })

      # Should have dark mode classes
      assert html =~ ~r/dark:|bg-gray-800|text-white/
      assert html =~ ~r/dark-theme/
    end

    test "applies industry-specific color schemes", %{offender: offender} do
      html = render_component(OffenderCard, %{offender: offender})

      # Should apply construction industry coloring
      assert html =~ ~r/construction|orange|amber/
      assert html =~ ~r/industry-construction/
    end

    test "supports custom CSS classes", %{offender: offender} do
      html = render_component(OffenderCard, %{
        offender: offender,
        class: "custom-card-class"
      })

      # Should include custom classes
      assert html =~ "custom-card-class"
    end
  end
end