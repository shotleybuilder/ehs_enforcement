defmodule EhsEnforcement.Enforcement.CaseTest do
  use EhsEnforcement.DataCase, async: true

  alias EhsEnforcement.Enforcement
  
  setup do
    # Create agency for testing
    {:ok, agency} = Enforcement.create_agency(%{
      code: :hse,
      name: "Health and Safety Executive"
    })

    {:ok, offender} = Enforcement.create_offender(%{
      name: "Test Company Ltd",
      local_authority: "Manchester"
    })

    %{agency: agency, offender: offender}
  end

  describe "case resource" do
    test "creates a case with valid attributes", %{agency: agency, offender: offender} do
      attrs = %{
        agency_id: agency.id,
        offender_id: offender.id,
        regulator_id: "HSE001",
        offence_result: "Guilty",
        offence_fine: Decimal.new("10000.00"),
        offence_costs: Decimal.new("2000.00"),
        offence_action_date: ~D[2024-01-15],
        offence_hearing_date: ~D[2024-01-10],
        offence_breaches: "Health and Safety at Work etc. Act 1974",
        regulator_function: "Construction Division"
      }

      assert {:ok, case_record} = Enforcement.create_case(attrs)
      assert case_record.regulator_id == "HSE001"
      assert case_record.offence_result == "Guilty"
      assert Decimal.equal?(case_record.offence_fine, Decimal.new("10000.00"))
      assert case_record.offence_action_date == ~D[2024-01-15]
      assert case_record.agency_id == agency.id
      assert case_record.offender_id == offender.id
    end

    test "creates case with agency code and offender attributes" do
      case_attrs = %{
        agency_code: :hse,
        offender_attrs: %{
          name: "New Company Ltd",
          local_authority: "Birmingham"
        },
        regulator_id: "HSE002",
        offence_result: "Guilty",
        offence_fine: Decimal.new("5000.00")
      }

      assert {:ok, case_record} = Enforcement.create_case(case_attrs)
      assert case_record.regulator_id == "HSE002"
      
      # Load with relationships
      case_with_relations = Enforcement.get_case!(
        case_record.id, 
        load: [:agency, :offender]
      )
      
      assert case_with_relations.agency.code == :hse
      assert case_with_relations.offender.name == "New Company Ltd"  # original preserved
      assert case_with_relations.offender.normalized_name == "new company limited"
    end

    test "validates required relationships" do
      attrs = %{
        regulator_id: "HSE003",
        offence_result: "Guilty"
      }

      assert {:error, %Ash.Error.Invalid{}} = Enforcement.create_case(attrs)
    end

    test "enforces unique airtable_id constraint" do
      attrs = %{
        agency_code: :hse,
        offender_attrs: %{name: "Test Company"},
        airtable_id: "rec123456",
        regulator_id: "HSE004"
      }

      assert {:ok, _case1} = Enforcement.create_case(attrs)
      
      attrs2 = %{
        agency_code: :hse,
        offender_attrs: %{name: "Different Company"},
        airtable_id: "rec123456",
        regulator_id: "HSE005"
      }

      assert {:error, %Ash.Error.Invalid{}} = Enforcement.create_case(attrs2)
    end

    test "filters cases by date range" do
      # Create cases with different dates
      attrs_base = %{
        agency_code: :hse,
        offender_attrs: %{name: "Test Company"}
      }

      {:ok, _case1} = Enforcement.create_case(Map.merge(attrs_base, %{
        regulator_id: "HSE001",
        offence_action_date: ~D[2024-01-01]
      }))

      {:ok, _case2} = Enforcement.create_case(Map.merge(attrs_base, %{
        regulator_id: "HSE002", 
        offence_action_date: ~D[2024-06-01]
      }))

      {:ok, _case3} = Enforcement.create_case(Map.merge(attrs_base, %{
        regulator_id: "HSE003",
        offence_action_date: ~D[2024-12-01]
      }))

      {:ok, cases} = Enforcement.list_cases_by_date_range(
        ~D[2024-05-01], 
        ~D[2024-07-01]
      )

      assert length(cases) == 1
      assert hd(cases).regulator_id == "HSE002"
    end

    test "calculates total penalty" do
      attrs = %{
        agency_code: :hse,
        offender_attrs: %{name: "Test Company"},
        regulator_id: "HSE001",
        offence_fine: Decimal.new("10000.00"),
        offence_costs: Decimal.new("2500.00")
      }

      assert {:ok, case_record} = Enforcement.create_case(attrs)
      
      case_with_calc = Enforcement.get_case!(
        case_record.id, 
        load: [:total_penalty]
      )
      
      expected_total = Decimal.new("12500.00")
      assert Decimal.equal?(case_with_calc.total_penalty, expected_total)
    end

    test "updates sync timestamp" do
      attrs = %{
        agency_code: :hse,
        offender_attrs: %{name: "Test Company"},
        regulator_id: "HSE001"
      }

      assert {:ok, case_record} = Enforcement.create_case(attrs)
      assert case_record.last_synced_at == nil

      sync_attrs = %{
        offence_result: "Updated result",
        offence_fine: Decimal.new("15000.00")
      }

      assert {:ok, updated_case} = Enforcement.sync_case(case_record, sync_attrs)
      assert updated_case.offence_result == "Updated result"
      assert updated_case.last_synced_at != nil
    end
  end
end