defmodule EhsEnforcement.Sync.OffenderMatcherTest do
  use EhsEnforcement.DataCase, async: true

  alias EhsEnforcement.Sync.OffenderMatcher
  alias EhsEnforcement.Enforcement

  describe "find_or_create_offender/1" do
    test "creates new offender when none exists" do
      attrs = %{
        name: "New Company Ltd",
        postcode: "M1 1AA",
        local_authority: "Manchester",
        business_type: :limited_company
      }

      # This will fail because OffenderMatcher module doesn't exist yet
      assert {:ok, offender} = OffenderMatcher.find_or_create_offender(attrs)
      assert offender.name == "New Company Ltd"  # original preserved
      assert offender.normalized_name == "new company limited"  # normalized version
      assert offender.postcode == "M1 1AA"
      assert offender.business_type == :limited_company
    end

    test "finds existing offender by exact name and postcode match" do
      # Create existing offender
      existing_attrs = %{
        name: "Existing Company Ltd",
        postcode: "M2 2BB"
      }
      {:ok, existing_offender} = Enforcement.create_offender(existing_attrs)

      # Try to find with same normalized data
      search_attrs = %{
        name: "Existing Company Ltd.",  # Different format but normalizes to same
        postcode: "M2 2BB",
        local_authority: "Different Authority"  # Additional data should be ignored for matching
      }

      assert {:ok, found_offender} = OffenderMatcher.find_or_create_offender(search_attrs)
      assert found_offender.id == existing_offender.id
      assert found_offender.name == "existing company limited"
    end

    test "creates new offender when postcode differs" do
      # Create existing offender
      {:ok, _existing} = Enforcement.create_offender(%{
        name: "Same Name Ltd",
        postcode: "M1 1AA"
      })

      # Try with same name but different postcode
      attrs = %{
        name: "Same Name Ltd",
        postcode: "M3 3CC"  # Different postcode
      }

      assert {:ok, new_offender} = OffenderMatcher.find_or_create_offender(attrs)
      assert new_offender.postcode == "M3 3CC"

      # Should have 2 offenders with same name but different postcodes
      {:ok, all_offenders} = Enforcement.list_offenders()
      same_name_offenders = Enum.filter(all_offenders, &(&1.name == "same name limited"))
      assert length(same_name_offenders) == 2
    end

    test "performs fuzzy search when exact match fails" do
      # Create offender with slight name variation
      {:ok, existing_offender} = Enforcement.create_offender(%{
        name: "ABC Construction Limited",
        postcode: "M4 4DD"
      })

      # Search with slightly different name
      search_attrs = %{
        name: "A.B.C. Construction Ltd",  # Should fuzzy match to existing
        postcode: "M4 4DD"
      }

      assert {:ok, found_offender} = OffenderMatcher.find_or_create_offender(search_attrs)
      assert found_offender.id == existing_offender.id
    end

    test "creates new offender when fuzzy match confidence is too low" do
      # Create offender
      {:ok, _existing} = Enforcement.create_offender(%{
        name: "Completely Different Company Ltd",
        postcode: "M5 5EE"
      })

      # Search with very different name
      search_attrs = %{
        name: "Totally Unrelated Business Ltd",
        postcode: "M6 6FF"
      }

      assert {:ok, new_offender} = OffenderMatcher.find_or_create_offender(search_attrs)
      assert new_offender.name == "totally unrelated business limited"
      assert new_offender.postcode == "M6 6FF"

      # Should have 2 different offenders
      {:ok, all_offenders} = Enforcement.list_offenders()
      assert length(all_offenders) == 2
    end

    test "handles multiple fuzzy matches by selecting best one" do
      # Create similar offenders
      {:ok, offender1} = Enforcement.create_offender(%{
        name: "ABC Construction Ltd",
        postcode: "M7 7GG"
      })
      
      {:ok, offender2} = Enforcement.create_offender(%{
        name: "ABC Building Ltd", 
        postcode: "M8 8HH"
      })

      # Search with name that could match either
      search_attrs = %{
        name: "ABC Construction Limited",  # Closer to first one
        postcode: "M7 7GG"  # Exact postcode match with first
      }

      assert {:ok, matched_offender} = OffenderMatcher.find_or_create_offender(search_attrs)
      assert matched_offender.id == offender1.id  # Should pick the better match
    end

    test "normalizes company name variations correctly" do
      # This will fail because OffenderMatcher module doesn't exist yet
      attrs = %{name: "Company Ltd.", postcode: "TEST"}
      {:ok, offender} = OffenderMatcher.find_or_create_offender(attrs)
      assert offender.name == "company limited"
    end

    test "handles missing postcode gracefully" do
      attrs = %{
        name: "No Postcode Company Ltd"
        # postcode deliberately omitted
      }

      # This will fail because OffenderMatcher module doesn't exist yet
      assert {:ok, offender} = OffenderMatcher.find_or_create_offender(attrs)
      assert offender.name == "no postcode company limited"
      assert offender.postcode == nil
    end

    test "handles empty or whitespace-only names" do
      attrs = %{
        name: "   ",  # Whitespace only
        postcode: "M9 9II"
      }

      # Should fail validation
      assert {:error, %Ash.Error.Invalid{}} = OffenderMatcher.find_or_create_offender(attrs)
    end

    test "finds offender when postcode case differs" do
      {:ok, existing} = Enforcement.create_offender(%{
        name: "Case Test Ltd",
        postcode: "m10 10jj"  # lowercase
      })

      search_attrs = %{
        name: "Case Test Ltd",
        postcode: "M10 10JJ"  # uppercase
      }

      assert {:ok, found_offender} = OffenderMatcher.find_or_create_offender(search_attrs)
      assert found_offender.id == existing.id
    end

    test "handles database constraint violations gracefully" do
      # This tests race conditions where two processes try to create the same offender
      attrs = %{
        name: "Race Condition Ltd",
        postcode: "M11 11KK"
      }

      # Simulate what happens if offender is created between find and create
      {:ok, _existing} = Enforcement.create_offender(attrs)

      # This should find the existing one instead of failing on constraint
      assert {:ok, found_offender} = OffenderMatcher.find_or_create_offender(attrs)
      assert found_offender.name == "race condition limited"
    end

    test "preserves additional attributes when creating new offender" do
      attrs = %{
        name: "Full Details Ltd",
        postcode: "M12 12LL",
        local_authority: "Test Authority",
        main_activity: "Testing",
        business_type: :limited_company,
        industry: "Software"
      }

      # This will fail because OffenderMatcher module doesn't exist yet
      assert {:ok, offender} = OffenderMatcher.find_or_create_offender(attrs)
      assert offender.local_authority == "Test Authority"
      assert offender.main_activity == "Testing"
      assert offender.business_type == :limited_company
      assert offender.industry == "Software"
    end

    test "performance with large dataset" do
      # Create many offenders
      Enum.each(1..100, fn i ->
        {:ok, _} = Enforcement.create_offender(%{
          name: "Performance Test Company #{i} Ltd",
          postcode: "PT#{i} #{i}XX"
        })
      end)

      # Search should still be fast
      attrs = %{
        name: "Performance Test Company 50 Ltd",
        postcode: "PT50 50XX"
      }

      {duration_us, result} = :timer.tc(fn ->
        OffenderMatcher.find_or_create_offender(attrs)
      end)

      assert {:ok, _offender} = result
      
      # Should complete in under 100ms even with 100 existing records
      duration_ms = duration_us / 1000
      assert duration_ms < 100
    end
  end

  describe "normalize_company_name/1" do
    test "normalizes various company name formats" do
      # This will fail because OffenderMatcher.normalize_company_name/1 doesn't exist yet
      assert OffenderMatcher.normalize_company_name("Test Company Ltd") == "test company limited"
      assert OffenderMatcher.normalize_company_name("Test Company Ltd.") == "test company limited"
      assert OffenderMatcher.normalize_company_name("Test Company LIMITED") == "test company limited"
      assert OffenderMatcher.normalize_company_name("Big Corp PLC") == "big corp plc"
      assert OffenderMatcher.normalize_company_name("Big Corp P.L.C.") == "big corp plc"
      assert OffenderMatcher.normalize_company_name("Simple Business") == "simple business"
    end

    test "handles extra whitespace" do
      assert OffenderMatcher.normalize_company_name("  Test Company  Ltd  ") == "test company limited"
      assert OffenderMatcher.normalize_company_name("Multiple   Spaces   Ltd") == "multiple spaces limited"
    end

    test "handles empty strings" do
      assert OffenderMatcher.normalize_company_name("") == ""
      assert OffenderMatcher.normalize_company_name("   ") == ""
    end
  end

  describe "find_best_match/2" do
    test "selects match with highest similarity score" do
      candidate1 = %{name: "abc construction", postcode: "M1 1AA", similarity: 0.7}
      candidate2 = %{name: "abc building", postcode: "M2 2BB", similarity: 0.9}
      candidate3 = %{name: "xyz company", postcode: "M3 3CC", similarity: 0.5}
      
      candidates = [candidate1, candidate2, candidate3]
      search_attrs = %{name: "ABC Building Ltd", postcode: "M2 2BB"}

      # This will fail because OffenderMatcher.find_best_match/2 doesn't exist yet
      result = OffenderMatcher.find_best_match(candidates, search_attrs)
      assert result.similarity == 0.9
    end

    test "prioritizes postcode match when similarity scores are close" do
      candidate1 = %{name: "test company", postcode: "M1 1AA", similarity: 0.85}
      candidate2 = %{name: "test business", postcode: "M5 5EE", similarity: 0.83}  # Same postcode as search
      
      candidates = [candidate1, candidate2]
      search_attrs = %{name: "Test Company Ltd", postcode: "M5 5EE"}

      # This will fail because OffenderMatcher.find_best_match/2 doesn't exist yet
      result = OffenderMatcher.find_best_match(candidates, search_attrs)
      assert result.postcode == "M5 5EE"  # Should prefer postcode match
    end

    test "returns nil when no candidates provided" do
      result = OffenderMatcher.find_best_match([], %{name: "Test", postcode: "M1 1AA"})
      assert result == nil
    end
  end
end