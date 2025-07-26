defmodule EhsEnforcement.Enforcement.OffenderTest do
  use EhsEnforcement.DataCase, async: true

  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Enforcement.Offender

  describe "offender resource" do
    test "creates an offender with valid attributes" do
      attrs = %{
        name: "Acme Construction Ltd",
        local_authority: "Manchester",
        postcode: "M1 1AA",
        main_activity: "Commercial construction",
        business_type: :limited_company,
        industry: "Construction"
      }

      assert {:ok, offender} = Enforcement.create_offender(attrs)
      assert offender.name == "Acme Construction Ltd"  # original name preserved
      assert offender.normalized_name == "acme construction limited"  # normalized version
      assert offender.local_authority == "Manchester"
      assert offender.postcode == "M1 1AA"
      assert offender.business_type == :limited_company
      assert offender.total_cases == 0
      assert offender.total_notices == 0
      assert offender.total_fines == Decimal.new("0")
    end

    test "normalizes company names" do
      attrs = %{
        name: "Test Company Ltd.",
        business_type: :limited_company
      }

      assert {:ok, offender} = Enforcement.create_offender(attrs)
      assert offender.name == "Test Company Ltd."  # original preserved
      assert offender.normalized_name == "test company limited"
    end

    test "normalizes PLC names" do
      attrs = %{
        name: "Big Corp P.L.C.",
        business_type: :plc
      }

      assert {:ok, offender} = Enforcement.create_offender(attrs)
      assert offender.name == "Big Corp P.L.C."  # original preserved
      assert offender.normalized_name == "big corp plc"
    end

    test "validates required name field" do
      attrs = %{}

      assert {:error, %Ash.Error.Invalid{}} = Enforcement.create_offender(attrs)
    end

    test "enforces unique name and postcode constraint" do
      attrs = %{
        name: "Duplicate Company Ltd",
        postcode: "M1 1AA"
      }

      assert {:ok, _offender1} = Enforcement.create_offender(attrs)
      assert {:error, %Ash.Error.Invalid{}} = Enforcement.create_offender(attrs)
    end

    test "allows same name with different postcodes" do
      attrs1 = %{name: "Same Company Ltd", postcode: "M1 1AA"}
      attrs2 = %{name: "Same Company Ltd", postcode: "M2 2BB"}

      assert {:ok, _offender1} = Enforcement.create_offender(attrs1)
      assert {:ok, _offender2} = Enforcement.create_offender(attrs2)
    end

    test "searches offenders by name" do
      attrs1 = %{name: "Construction Company Ltd"}
      attrs2 = %{name: "Building Services Ltd"}
      attrs3 = %{name: "Electrical Services Ltd"}

      assert {:ok, _} = Enforcement.create_offender(attrs1)
      assert {:ok, _} = Enforcement.create_offender(attrs2)
      assert {:ok, _} = Enforcement.create_offender(attrs3)

      {:ok, results} = Enforcement.search_offenders("construction")
      assert length(results) == 1

      {:ok, results} = Enforcement.search_offenders("services")
      assert length(results) == 2
    end

    test "updates offender statistics" do
      attrs = %{name: "Test Company Ltd"}
      assert {:ok, offender} = Enforcement.create_offender(attrs)

      fine_amount = Decimal.new("5000.00")
      assert {:ok, updated_offender} = Enforcement.update_offender_statistics(
        offender, 
        %{fine_amount: fine_amount}
      )

      assert updated_offender.total_cases == 1
      assert updated_offender.total_notices == 1
      assert Decimal.equal?(updated_offender.total_fines, fine_amount)
    end

    test "calculates enforcement count" do
      attrs = %{
        name: "Test Company Ltd"
      }

      assert {:ok, offender} = Enforcement.create_offender(attrs)
      
      # Update statistics separately using the update_statistics action
      assert {:ok, updated_offender} = Enforcement.update_offender_statistics(
        offender, 
        %{fine_amount: Decimal.new("1000")}
      )
      
      # Load with calculation - should be total_cases + total_notices
      {:ok, offender_with_calc} = Enforcement.get_offender!(updated_offender.id, load: [:enforcement_count])
      # After one update_statistics call, total_cases = 1, total_notices = 1
      assert offender_with_calc.enforcement_count == 2
    end
  end
end