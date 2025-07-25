defmodule EhsEnforcement.Config.FeatureFlagsTest do
  use ExUnit.Case, async: true

  alias EhsEnforcement.Config.FeatureFlags

  describe "enabled?/1" do
    test "returns true for permanently enabled features" do
      # This will fail because FeatureFlags module doesn't exist yet
      assert FeatureFlags.enabled?(:manual_sync) == true
      assert FeatureFlags.enabled?(:export_enabled) == true
    end

    test "returns false for disabled features by default" do
      System.delete_env("AUTO_SYNC_ENABLED")
      
      assert FeatureFlags.enabled?(:auto_sync) == false
    end

    test "respects environment variable for auto_sync" do
      System.put_env("AUTO_SYNC_ENABLED", "true")
      assert FeatureFlags.enabled?(:auto_sync) == true
      
      System.put_env("AUTO_SYNC_ENABLED", "false")
      assert FeatureFlags.enabled?(:auto_sync) == false
      
      System.delete_env("AUTO_SYNC_ENABLED")
    end

    test "handles case-insensitive boolean strings" do
      System.put_env("AUTO_SYNC_ENABLED", "TRUE")
      assert FeatureFlags.enabled?(:auto_sync) == true
      
      System.put_env("AUTO_SYNC_ENABLED", "False")
      assert FeatureFlags.enabled?(:auto_sync) == false
      
      System.put_env("AUTO_SYNC_ENABLED", "1")
      assert FeatureFlags.enabled?(:auto_sync) == true
      
      System.put_env("AUTO_SYNC_ENABLED", "0")
      assert FeatureFlags.enabled?(:auto_sync) == false
      
      System.delete_env("AUTO_SYNC_ENABLED")
    end

    test "returns false for unknown features" do
      assert FeatureFlags.enabled?(:nonexistent_feature) == false
    end

    test "handles malformed environment variables gracefully" do
      System.put_env("AUTO_SYNC_ENABLED", "maybe")
      
      # Should default to false for invalid values
      assert FeatureFlags.enabled?(:auto_sync) == false
      
      System.delete_env("AUTO_SYNC_ENABLED")
    end
  end

  describe "all_flags/0" do
    test "returns all configured feature flags with their status" do
      flags = FeatureFlags.all_flags()
      
      assert is_map(flags)
      assert Map.has_key?(flags, :auto_sync)
      assert Map.has_key?(flags, :manual_sync)
      assert Map.has_key?(flags, :export_enabled)
      
      assert is_boolean(flags[:auto_sync])
      assert is_boolean(flags[:manual_sync])
      assert is_boolean(flags[:export_enabled])
    end

    test "reflects current environment variable state" do
      System.put_env("AUTO_SYNC_ENABLED", "true")
      
      flags = FeatureFlags.all_flags()
      assert flags[:auto_sync] == true
      
      System.put_env("AUTO_SYNC_ENABLED", "false")
      flags = FeatureFlags.all_flags()
      assert flags[:auto_sync] == false
      
      System.delete_env("AUTO_SYNC_ENABLED")
    end
  end

  describe "enable_for_test/1" do
    test "temporarily enables feature for testing" do
      # Initially disabled
      System.delete_env("AUTO_SYNC_ENABLED")
      assert FeatureFlags.enabled?(:auto_sync) == false
      
      # Enable for test
      FeatureFlags.enable_for_test(:auto_sync)
      assert FeatureFlags.enabled?(:auto_sync) == true
      
      # Should remain enabled until reset
      assert FeatureFlags.enabled?(:auto_sync) == true
    end

    test "can enable multiple features for testing" do
      FeatureFlags.enable_for_test(:auto_sync)
      FeatureFlags.enable_for_test(:test_feature)
      
      assert FeatureFlags.enabled?(:auto_sync) == true
      assert FeatureFlags.enabled?(:test_feature) == true
    end
  end

  describe "disable_for_test/1" do
    test "temporarily disables feature for testing" do
      # Ensure feature is enabled
      System.put_env("AUTO_SYNC_ENABLED", "true")
      assert FeatureFlags.enabled?(:auto_sync) == true
      
      # Disable for test
      FeatureFlags.disable_for_test(:auto_sync)
      assert FeatureFlags.enabled?(:auto_sync) == false
      
      System.delete_env("AUTO_SYNC_ENABLED")
    end

    test "can disable permanently enabled features for testing" do
      # manual_sync is permanently enabled
      assert FeatureFlags.enabled?(:manual_sync) == true
      
      # But we can disable it for testing
      FeatureFlags.disable_for_test(:manual_sync)
      assert FeatureFlags.enabled?(:manual_sync) == false
    end
  end

  describe "reset_test_overrides/0" do
    test "resets all test overrides to environment/default values" do
      # Set some test overrides
      FeatureFlags.enable_for_test(:auto_sync)
      FeatureFlags.disable_for_test(:manual_sync)
      
      assert FeatureFlags.enabled?(:auto_sync) == true
      assert FeatureFlags.enabled?(:manual_sync) == false
      
      # Reset overrides
      FeatureFlags.reset_test_overrides()
      
      # Should return to original state
      System.delete_env("AUTO_SYNC_ENABLED")
      assert FeatureFlags.enabled?(:auto_sync) == false  # Default
      assert FeatureFlags.enabled?(:manual_sync) == true  # Permanently enabled
    end
  end

  describe "get_flag_source/1" do
    test "identifies source of feature flag value" do
      # Environment variable source
      System.put_env("AUTO_SYNC_ENABLED", "true")
      assert FeatureFlags.get_flag_source(:auto_sync) == :environment
      
      # Default source
      System.delete_env("AUTO_SYNC_ENABLED")
      assert FeatureFlags.get_flag_source(:auto_sync) == :default
      
      # Test override source
      FeatureFlags.enable_for_test(:auto_sync)
      assert FeatureFlags.get_flag_source(:auto_sync) == :test_override
      
      FeatureFlags.reset_test_overrides()
    end

    test "identifies permanent flag source" do
      assert FeatureFlags.get_flag_source(:manual_sync) == :permanent
      assert FeatureFlags.get_flag_source(:export_enabled) == :permanent
    end

    test "returns :unknown for nonexistent flags" do
      assert FeatureFlags.get_flag_source(:nonexistent) == :unknown
    end
  end

  describe "validate_flag_name/1" do
    test "validates known feature flag names" do
      assert FeatureFlags.validate_flag_name(:auto_sync) == :ok
      assert FeatureFlags.validate_flag_name(:manual_sync) == :ok
      assert FeatureFlags.validate_flag_name(:export_enabled) == :ok
    end

    test "rejects unknown feature flag names" do
      assert FeatureFlags.validate_flag_name(:unknown_flag) == {:error, :unknown_flag}
      assert FeatureFlags.validate_flag_name(:typo_flag) == {:error, :unknown_flag}
    end

    test "handles string flag names" do
      assert FeatureFlags.validate_flag_name("auto_sync") == :ok
      assert FeatureFlags.validate_flag_name("unknown") == {:error, :unknown_flag}
    end
  end

  describe "flag_descriptions/0" do
    test "returns human-readable descriptions for all flags" do
      descriptions = FeatureFlags.flag_descriptions()
      
      assert is_map(descriptions)
      assert Map.has_key?(descriptions, :auto_sync)
      assert Map.has_key?(descriptions, :manual_sync)
      assert Map.has_key?(descriptions, :export_enabled)
      
      # All descriptions should be strings
      Enum.each(descriptions, fn {_flag, description} ->
        assert is_binary(description)
        assert String.length(description) > 0
      end)
    end

    test "includes information about configuration method" do
      descriptions = FeatureFlags.flag_descriptions()
      
      # auto_sync should mention environment variable
      assert descriptions[:auto_sync] =~ "AUTO_SYNC_ENABLED"
      
      # manual_sync should indicate it's permanently enabled
      assert descriptions[:manual_sync] =~ "permanently"
    end
  end

  describe "environment_variable_for/1" do
    test "returns correct environment variable name for configurable flags" do
      assert FeatureFlags.environment_variable_for(:auto_sync) == "AUTO_SYNC_ENABLED"
    end

    test "returns nil for permanently configured flags" do
      assert FeatureFlags.environment_variable_for(:manual_sync) == nil
      assert FeatureFlags.environment_variable_for(:export_enabled) == nil
    end

    test "returns nil for unknown flags" do
      assert FeatureFlags.environment_variable_for(:unknown_flag) == nil
    end
  end

  describe "flag_status_summary/0" do
    test "provides comprehensive status summary for all flags" do
      summary = FeatureFlags.flag_status_summary()
      
      assert is_map(summary)
      assert Map.has_key?(summary, :enabled_count)
      assert Map.has_key?(summary, :disabled_count)
      assert Map.has_key?(summary, :flags)
      
      assert is_integer(summary[:enabled_count])
      assert is_integer(summary[:disabled_count])
      assert is_map(summary[:flags])
    end

    test "counts enabled and disabled flags correctly" do
      System.delete_env("AUTO_SYNC_ENABLED")  # auto_sync disabled
      FeatureFlags.reset_test_overrides()
      
      summary = FeatureFlags.flag_status_summary()
      
      # manual_sync and export_enabled are permanently enabled
      # auto_sync is disabled by default
      assert summary[:enabled_count] >= 2
      assert summary[:disabled_count] >= 1
      assert summary[:enabled_count] + summary[:disabled_count] == map_size(summary[:flags])
    end
  end
end