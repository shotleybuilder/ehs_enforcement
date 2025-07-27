defmodule EhsEnforcement.Config.SettingsTest do
  use ExUnit.Case, async: true

  alias EhsEnforcement.Config.Settings

  describe "get_airtable_config/0" do
    test "returns airtable configuration with required fields" do
      # Set environment variable for this test
      System.put_env("AT_UK_E_API_KEY", "test_api_key_12345")
      
      config = Settings.get_airtable_config()
      
      assert config[:api_key] != nil
      assert config[:base_id] != nil
      assert is_integer(config[:sync_interval_minutes])
      
      # Clean up
      System.delete_env("AT_UK_E_API_KEY")
    end

    test "uses default values when environment variables are not set" do
      # Test default fallback behavior
      config = Settings.get_airtable_config()
      
      # Should have default base_id
      assert config[:base_id] == "appq5OQW9bTHC1zO5"
      # Should have default sync interval
      assert config[:sync_interval_minutes] == 60
    end

    test "parses sync_interval from string to integer" do
      # Test that string environment variables are properly converted
      System.put_env("SYNC_INTERVAL", "120")
      
      config = Settings.get_airtable_config()
      assert config[:sync_interval_minutes] == 120
      
      # Clean up
      System.delete_env("SYNC_INTERVAL")
    end

    test "handles invalid sync_interval gracefully" do
      System.put_env("SYNC_INTERVAL", "invalid")
      
      # Should fall back to default instead of crashing
      config = Settings.get_airtable_config()
      assert config[:sync_interval_minutes] == 60
      
      System.delete_env("SYNC_INTERVAL")
    end
  end

  describe "get_agency_config/1" do
    test "returns HSE agency configuration" do
      config = Settings.get_agency_config(:hse)
      
      assert config[:enabled] == true
      assert config[:base_url] == "https://resources.hse.gov.uk"
      assert is_map(config[:tables])
      assert config[:tables][:cases] != nil
      assert config[:tables][:notices] != nil
    end

    test "respects HSE_ENABLED environment variable" do
      System.put_env("HSE_ENABLED", "false")
      
      config = Settings.get_agency_config(:hse)
      assert config[:enabled] == false
      
      System.delete_env("HSE_ENABLED")
    end

    test "returns nil for unknown agency" do
      config = Settings.get_agency_config(:unknown_agency)
      assert config == nil
    end

    test "returns default enabled=true when HSE_ENABLED not set" do
      # Ensure no environment variable is set
      System.delete_env("HSE_ENABLED")
      
      config = Settings.get_agency_config(:hse)
      assert config[:enabled] == true
    end
  end

  describe "get_feature_flags/0" do
    test "returns feature flag configuration" do
      flags = Settings.get_feature_flags()
      
      assert is_boolean(flags[:auto_sync])
      assert flags[:manual_sync] == true
      assert flags[:export_enabled] == true
    end

    test "respects AUTO_SYNC_ENABLED environment variable" do
      System.put_env("AUTO_SYNC_ENABLED", "true")
      
      flags = Settings.get_feature_flags()
      assert flags[:auto_sync] == true
      
      System.put_env("AUTO_SYNC_ENABLED", "false")
      flags = Settings.get_feature_flags()
      assert flags[:auto_sync] == false
      
      System.delete_env("AUTO_SYNC_ENABLED")
    end

    test "defaults auto_sync to false when not specified" do
      System.delete_env("AUTO_SYNC_ENABLED")
      
      flags = Settings.get_feature_flags()
      assert flags[:auto_sync] == false
    end
  end

  describe "validate_configuration/0" do
    test "returns :ok when all required configuration is present" do
      # Mock required environment variables
      System.put_env("AT_UK_E_API_KEY", "test_key_12345")
      System.put_env("DATABASE_URL", "postgresql://test:test@localhost/test_db")
      
      assert Settings.validate_configuration() == :ok
      
      # Clean up
      System.delete_env("AT_UK_E_API_KEY")
      System.delete_env("DATABASE_URL")
    end

    test "returns error when required AT_UK_E_API_KEY is missing" do
      System.delete_env("AT_UK_E_API_KEY")
      
      assert {:error, :missing_airtable_api_key} = Settings.validate_configuration()
    end

    test "returns error when required DATABASE_URL is missing" do
      System.put_env("AT_UK_E_API_KEY", "test_key")
      System.delete_env("DATABASE_URL")
      
      assert {:error, :missing_database_url} = Settings.validate_configuration()
      
      System.delete_env("AT_UK_E_API_KEY")
    end

    test "validates sync_interval is a valid integer" do
      System.put_env("AT_UK_E_API_KEY", "test_key_12345")
      System.put_env("DATABASE_URL", "postgresql://test:test@localhost/test_db")
      System.put_env("SYNC_INTERVAL", "not_a_number")
      
      assert {:error, :invalid_sync_interval} = Settings.validate_configuration()
      
      # Clean up
      System.delete_env("AT_UK_E_API_KEY")
      System.delete_env("DATABASE_URL")
      System.delete_env("SYNC_INTERVAL")
    end
  end

  describe "feature_enabled?/1" do
    test "returns true for enabled features" do
      assert Settings.feature_enabled?(:manual_sync) == true
      assert Settings.feature_enabled?(:export_enabled) == true
    end

    test "returns false for disabled features" do
      System.delete_env("AUTO_SYNC_ENABLED")
      assert Settings.feature_enabled?(:auto_sync) == false
    end

    test "respects runtime feature flag changes" do
      System.put_env("AUTO_SYNC_ENABLED", "true")
      assert Settings.feature_enabled?(:auto_sync) == true
      
      System.put_env("AUTO_SYNC_ENABLED", "false")
      assert Settings.feature_enabled?(:auto_sync) == false
      
      System.delete_env("AUTO_SYNC_ENABLED")
    end

    test "returns false for unknown features" do
      assert Settings.feature_enabled?(:unknown_feature) == false
    end
  end

  describe "get_all_agencies/0" do
    test "returns list of all configured agencies" do
      agencies = Settings.get_all_agencies()
      
      assert is_list(agencies)
      assert :hse in agencies
    end

    test "only returns enabled agencies" do
      System.put_env("HSE_ENABLED", "false")
      
      agencies = Settings.get_all_agencies()
      refute :hse in agencies
      
      System.delete_env("HSE_ENABLED")
    end
  end

  describe "get_database_config/0" do
    test "returns database configuration" do
      System.put_env("DATABASE_URL", "postgresql://user:pass@localhost/ehs_enforcement")
      
      config = Settings.get_database_config()
      assert config[:url] == "postgresql://user:pass@localhost/ehs_enforcement"
      
      System.delete_env("DATABASE_URL")
    end

    test "includes pool size configuration" do
      config = Settings.get_database_config()
      assert is_integer(config[:pool_size])
      assert config[:pool_size] > 0
    end
  end
end