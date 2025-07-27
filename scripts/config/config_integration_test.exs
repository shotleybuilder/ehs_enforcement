defmodule EhsEnforcement.Config.ConfigIntegrationTest do
  use ExUnit.Case, async: false  # Not async due to environment variable changes

  alias EhsEnforcement.Config.{Settings, Validator, FeatureFlags, ConfigManager, Environment}

  describe "full configuration system integration" do
    setup do
      # Store original environment variables
      original_env = %{
        api_key: System.get_env("AT_UK_E_API_KEY"),
        database_url: System.get_env("DATABASE_URL"),
        secret_key: System.get_env("SECRET_KEY_BASE"),
        sync_interval: System.get_env("SYNC_INTERVAL"),
        hse_enabled: System.get_env("HSE_ENABLED"),
        auto_sync: System.get_env("AUTO_SYNC_ENABLED")
      }

      # Clean up environment
      System.delete_env("AT_UK_E_API_KEY")
      System.delete_env("DATABASE_URL")
      System.delete_env("SECRET_KEY_BASE")
      System.delete_env("SYNC_INTERVAL")
      System.delete_env("HSE_ENABLED")
      System.delete_env("AUTO_SYNC_ENABLED")

      on_exit(fn ->
        # Restore original environment
        for {key, value} <- [
          {"AT_UK_E_API_KEY", original_env.api_key},
          {"DATABASE_URL", original_env.database_url},
          {"SECRET_KEY_BASE", original_env.secret_key},
          {"SYNC_INTERVAL", original_env.sync_interval},
          {"HSE_ENABLED", original_env.hse_enabled},
          {"AUTO_SYNC_ENABLED", original_env.auto_sync}
        ] do
          if value do
            System.put_env(key, value)
          else
            System.delete_env(key)
          end
        end
      end)

      :ok
    end

    test "complete application startup configuration flow" do
      # 1. Set up minimal required configuration
      System.put_env("AT_UK_E_API_KEY", "test_api_key_12345")
      System.put_env("DATABASE_URL", "postgresql://user:pass@localhost/ehs_enforcement_test")
      System.put_env("SECRET_KEY_BASE", String.duplicate("a", 64))

      # 2. Validate configuration on startup
      # This will fail until modules are implemented
      assert Validator.validate_on_startup() == :ok

      # 3. Load all configuration
      airtable_config = Settings.get_airtable_config()
      assert airtable_config[:api_key] == "test_api_key_12345"
      assert airtable_config[:sync_interval_minutes] == 60  # Default

      # 4. Verify feature flags work
      assert FeatureFlags.enabled?(:manual_sync) == true
      assert FeatureFlags.enabled?(:auto_sync) == false  # Default

      # 5. Test configuration management
      all_config = ConfigManager.get_all_config()
      assert is_map(all_config)
      assert all_config[:airtable][:api_key] == "***MASKED***"  # Should be masked
    end

    test "configuration changes propagate through system" do
      # Set initial configuration
      System.put_env("AT_UK_E_API_KEY", "initial_key_12345")
      System.put_env("DATABASE_URL", "postgresql://user:pass@localhost/test_db")
      System.put_env("SECRET_KEY_BASE", String.duplicate("b", 64))
      System.put_env("AUTO_SYNC_ENABLED", "false")

      # Verify initial state
      assert FeatureFlags.enabled?(:auto_sync) == false

      # Change environment variable
      System.put_env("AUTO_SYNC_ENABLED", "true")

      # Reload configuration
      ConfigManager.reload_config()

      # Verify change propagated
      assert FeatureFlags.enabled?(:auto_sync) == true
    end

    test "invalid configuration is caught at multiple levels" do
      # Set invalid configuration
      System.put_env("AT_UK_E_API_KEY", "short")  # Too short
      System.put_env("DATABASE_URL", "invalid_url")
      System.put_env("SYNC_INTERVAL", "not_a_number")

      # Should fail at validation level
      assert {:error, errors} = Validator.validate_on_startup()
      assert is_list(errors)
      assert length(errors) > 1

      # Should fail at environment level
      assert {:error, _} = Environment.validate_var("AT_UK_E_API_KEY", "short")
      assert {:error, _} = Environment.validate_var("DATABASE_URL", "invalid_url")
      assert {:error, _} = Environment.validate_var("SYNC_INTERVAL", "not_a_number")

      # Should fail at config manager level
      assert {:error, config_errors} = ConfigManager.validate_all_config()
      assert length(config_errors) > 0
    end

    test "feature flags work correctly with environment variables" do
      # Set up basic required config
      System.put_env("AT_UK_E_API_KEY", "test_key_12345")
      System.put_env("DATABASE_URL", "postgresql://user:pass@localhost/test_db")
      System.put_env("SECRET_KEY_BASE", String.duplicate("c", 64))

      # Test auto_sync feature flag
      System.delete_env("AUTO_SYNC_ENABLED")
      assert FeatureFlags.enabled?(:auto_sync) == false

      System.put_env("AUTO_SYNC_ENABLED", "true")
      assert FeatureFlags.enabled?(:auto_sync) == true

      System.put_env("AUTO_SYNC_ENABLED", "false")
      assert FeatureFlags.enabled?(:auto_sync) == false

      # Test HSE agency enable/disable
      System.delete_env("HSE_ENABLED")
      hse_config = Settings.get_agency_config(:hse)
      assert hse_config[:enabled] == true  # Default

      System.put_env("HSE_ENABLED", "false")
      ConfigManager.reload_config()
      hse_config = Settings.get_agency_config(:hse)
      assert hse_config[:enabled] == false
    end

    test "configuration documentation and export work" do
      # Set up configuration
      System.put_env("AT_UK_E_API_KEY", "test_key_12345")
      System.put_env("DATABASE_URL", "postgresql://user:pass@localhost/test_db")
      System.put_env("SECRET_KEY_BASE", String.duplicate("d", 64))
      System.put_env("SYNC_INTERVAL", "120")

      # Test documentation generation
      docs = Environment.get_environment_documentation()
      assert is_binary(docs)
      assert docs =~ "AT_UK_E_API_KEY"
      assert docs =~ "Required"

      # Test configuration export
      json_export = ConfigManager.export_config(:json)
      assert is_binary(json_export)
      parsed = Jason.decode!(json_export)
      assert is_map(parsed)

      # Test environment template generation
      env_template = Environment.export_template(:env)
      assert is_binary(env_template)
      assert env_template =~ "AT_UK_E_API_KEY="
    end

    test "configuration validation catches cross-dependencies" do
      # Enable auto_sync but don't provide Airtable config
      System.put_env("AUTO_SYNC_ENABLED", "true")
      System.delete_env("AT_UK_E_API_KEY")  # Required for auto_sync
      System.put_env("DATABASE_URL", "postgresql://user:pass@localhost/test_db")
      System.put_env("SECRET_KEY_BASE", String.duplicate("e", 64))

      # Should catch dependency error
      assert {:error, errors} = ConfigManager.validate_all_config()
      assert :auto_sync_requires_airtable_config in errors
    end

    test "agency configuration integration" do
      # Set up basic config
      System.put_env("AT_UK_E_API_KEY", "test_key_12345")
      System.put_env("DATABASE_URL", "postgresql://user:pass@localhost/test_db")
      System.put_env("SECRET_KEY_BASE", String.duplicate("f", 64))

      # Test HSE agency configuration
      hse_config = Settings.get_agency_config(:hse)
      assert hse_config[:base_url] == "https://resources.hse.gov.uk"
      assert is_map(hse_config[:tables])

      # Test agency validation
      assert Validator.validate_agency_config(:hse) == :ok
      assert {:error, :unknown_agency} = Validator.validate_agency_config(:unknown)

      # Test all agencies list
      all_agencies = Settings.get_all_agencies()
      assert :hse in all_agencies

      # Disable HSE and verify it's removed from active list
      System.put_env("HSE_ENABLED", "false")
      ConfigManager.reload_config()
      active_agencies = Settings.get_all_agencies()
      refute :hse in active_agencies
    end

    test "configuration change notifications work" do
      # Set up basic config
      System.put_env("AT_UK_E_API_KEY", "test_key_12345")
      System.put_env("DATABASE_URL", "postgresql://user:pass@localhost/test_db")
      System.put_env("SECRET_KEY_BASE", String.duplicate("g", 64))

      # Subscribe to configuration changes
      ConfigManager.watch_config_changes(self())

      # Make a configuration change
      ConfigManager.set_config(:features, :test_notification, true)

      # Should receive notification
      assert_receive {:config_changed, :features, :test_notification, true}, 1000
    end

    test "environment summary provides complete overview" do
      # Set up partial configuration
      System.put_env("AT_UK_E_API_KEY", "test_key_12345")
      System.delete_env("DATABASE_URL")  # Leave this missing
      System.put_env("SECRET_KEY_BASE", String.duplicate("h", 64))
      System.put_env("AUTO_SYNC_ENABLED", "true")

      # Get environment summary
      summary = ConfigManager.get_environment_summary()

      assert summary[:environment] == :test
      assert "DATABASE_URL" in summary[:missing_required]
      assert summary[:feature_flags][:auto_sync] == true
      assert summary[:feature_flags][:manual_sync] == true
    end

    test ".env file loading integration" do
      # Create test .env file
      env_content = """
      AT_UK_E_API_KEY=env_file_key_12345
      DATABASE_URL=postgresql://env:env@localhost/env_db
      SECRET_KEY_BASE=#{String.duplicate("i", 64)}
      SYNC_INTERVAL=240
      AUTO_SYNC_ENABLED=true
      HSE_ENABLED=false
      """

      File.write!("/tmp/integration_test.env", env_content)

      # Load from file
      assert Environment.load_from_file("/tmp/integration_test.env") == :ok

      # Verify all settings propagated correctly
      assert Settings.get_airtable_config()[:api_key] == "env_file_key_12345"
      assert Settings.get_airtable_config()[:sync_interval_minutes] == 240
      assert FeatureFlags.enabled?(:auto_sync) == true
      assert Settings.get_agency_config(:hse)[:enabled] == false

      # Validate everything is working
      assert Validator.validate_on_startup() == :ok

      # Clean up
      File.rm("/tmp/integration_test.env")
    end
  end

  describe "configuration system error handling" do
    test "gracefully handles missing configuration files" do
      result = Environment.load_from_file("/nonexistent/config.env")
      assert {:error, :file_not_found} = result
      
      # System should still work with environment variables
      System.put_env("AT_UK_E_API_KEY", "fallback_key_12345")
      System.put_env("DATABASE_URL", "postgresql://fallback@localhost/db")
      System.put_env("SECRET_KEY_BASE", String.duplicate("j", 64))
      
      assert Validator.validate_on_startup() == :ok
    end

    test "handles partial configuration gracefully" do
      # Only set some required variables
      System.put_env("AT_UK_E_API_KEY", "partial_key_12345")
      # Missing DATABASE_URL and SECRET_KEY_BASE

      # Should identify what's missing
      missing = Environment.check_missing_required()
      assert "DATABASE_URL" in missing
      assert "SECRET_KEY_BASE" in missing

      # But shouldn't crash
      config = Settings.get_airtable_config()
      assert config[:api_key] == "partial_key_12345"
    end

    test "feature flags work even with invalid main configuration" do
      # Set invalid main config but valid feature flag config
      System.put_env("AT_UK_E_API_KEY", "short")  # Invalid
      System.put_env("AUTO_SYNC_ENABLED", "true")  # Valid

      # Feature flags should still work
      assert FeatureFlags.enabled?(:auto_sync) == true
      assert FeatureFlags.enabled?(:manual_sync) == true

      # But validation should catch the main config issue
      assert {:error, _} = Validator.validate_on_startup()
    end
  end
end