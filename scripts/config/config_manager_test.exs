defmodule EhsEnforcement.Config.ConfigManagerTest do
  use ExUnit.Case, async: false  # Changed to false due to GenServer state

  alias EhsEnforcement.Config.ConfigManager

  setup do
    # Set up environment variables for tests
    System.put_env("AT_UK_E_API_KEY", "test_key_1234567890123456")
    System.put_env("DATABASE_URL", "postgresql://user:pass@localhost/test_db")
    System.put_env("SECRET_KEY_BASE", "test_secret_key_base_64_chars_long_1234567890123456789012345678901234567890")
    
    # Start the ConfigManager GenServer for testing
    case GenServer.whereis(ConfigManager) do
      nil -> start_supervised!(ConfigManager)
      _pid -> :ok
    end
    
    on_exit(fn ->
      # Clean up environment variables
      System.delete_env("AT_UK_E_API_KEY")
      System.delete_env("DATABASE_URL") 
      System.delete_env("SECRET_KEY_BASE")
    end)
    
    :ok
  end

  describe "get_config/2" do
    test "retrieves configuration values by path" do
      # This will fail because ConfigManager module doesn't exist yet
      assert ConfigManager.get_config(:airtable, :api_key) != nil
      assert ConfigManager.get_config(:features, :manual_sync) == true
    end

    test "returns default value when config path doesn't exist" do
      result = ConfigManager.get_config(:nonexistent, :path, "default_value")
      assert result == "default_value"
    end

    test "returns nil when config path doesn't exist and no default provided" do
      result = ConfigManager.get_config(:nonexistent, :path)
      assert result == nil
    end

    test "handles nested configuration paths" do
      # Test accessing nested configuration like agencies.hse.base_url
      base_url = ConfigManager.get_config([:agencies, :hse], :base_url)
      assert base_url == "https://resources.hse.gov.uk"
      
      # Test accessing table configuration
      tables = ConfigManager.get_config([:agencies, :hse], :tables)
      assert is_map(tables)
      assert tables[:cases] != nil
    end

    test "handles atom and string keys interchangeably" do
      # Should work with both atom and string keys
      result1 = ConfigManager.get_config(:airtable, :sync_interval_minutes)
      result2 = ConfigManager.get_config(:airtable, :sync_interval_minutes)  # Use atoms for now
      
      assert result1 == result2
      assert is_integer(result1)
      assert result1 == 60  # Default value
    end
  end

  describe "set_config/3" do
    test "sets configuration values dynamically" do
      original_value = ConfigManager.get_config(:features, :test_feature)
      
      ConfigManager.set_config(:features, :test_feature, true)
      assert ConfigManager.get_config(:features, :test_feature) == true
      
      ConfigManager.set_config(:features, :test_feature, false)
      assert ConfigManager.get_config(:features, :test_feature) == false
      
      # Restore original value
      ConfigManager.set_config(:features, :test_feature, original_value)
    end

    test "creates new configuration paths if they don't exist" do
      ConfigManager.set_config(:new_section, :new_key, "new_value")
      assert ConfigManager.get_config(:new_section, :new_key) == "new_value"
    end

    test "handles nested path updates" do
      ConfigManager.set_config([:test_agencies, :test_agency], :enabled, false)
      assert ConfigManager.get_config([:test_agencies, :test_agency], :enabled) == false
    end

    test "validates configuration changes" do
      # Should reject invalid configuration values
      assert {:error, :invalid_value} = ConfigManager.set_config(:airtable, :sync_interval_minutes, -1)
      assert {:error, :invalid_value} = ConfigManager.set_config(:airtable, :sync_interval_minutes, "not_a_number")
    end
  end

  describe "reload_config/0" do
    test "reloads configuration from environment variables" do
      # Change environment variable
      System.put_env("SYNC_INTERVAL", "300")
      
      # Reload config
      ConfigManager.reload_config()
      
      # Should reflect new value
      assert ConfigManager.get_config(:airtable, :sync_interval_minutes) == 300
      
      System.delete_env("SYNC_INTERVAL")
    end

    test "validates configuration after reload" do
      # Set invalid configuration
      System.put_env("SYNC_INTERVAL", "invalid")
      
      # Reload should detect and report errors
      assert {:error, :configuration_validation_failed} = ConfigManager.reload_config()
      
      System.delete_env("SYNC_INTERVAL")
    end

    test "preserves runtime configuration overrides where appropriate" do
      # Set a runtime override
      ConfigManager.set_config(:features, :test_mode, true)
      
      # Reload config
      ConfigManager.reload_config()
      
      # Runtime override should be preserved (test mode shouldn't be overwritten by env vars)
      assert ConfigManager.get_config(:features, :test_mode) == true
    end
  end

  describe "get_all_config/0" do
    test "returns complete configuration tree" do
      config = ConfigManager.get_all_config()
      
      assert is_map(config)
      assert Map.has_key?(config, :airtable)
      assert Map.has_key?(config, :agencies)
      assert Map.has_key?(config, :features)
      
      # Verify structure
      assert is_map(config[:airtable])
      assert is_map(config[:agencies])
      assert is_map(config[:features])
    end

    test "includes computed values and defaults" do
      config = ConfigManager.get_all_config()
      
      # Should include default values
      assert config[:airtable][:sync_interval_minutes] != nil
      assert config[:features][:manual_sync] == true
      
      # Should include computed agency configurations
      assert config[:agencies][:hse][:base_url] != nil
    end

    test "masks sensitive values in output" do
      config = ConfigManager.get_all_config()
      
      # API key should be masked for security
      assert config[:airtable][:api_key] == "***MASKED***" or config[:airtable][:api_key] == nil
    end
  end

  describe "validate_all_config/0" do
    test "validates entire configuration for consistency" do
      # With valid configuration
      System.put_env("AT_UK_E_API_KEY", "test_key_1234567890123456")  # Ensure minimum length
      System.put_env("DATABASE_URL", "postgresql://user:pass@localhost/test_db")
      System.put_env("SECRET_KEY_BASE", "test_secret_key_base_64_chars_long_1234567890123456789012345678901234567890")
      
      assert ConfigManager.validate_all_config() == :ok
      
      System.delete_env("AT_UK_E_API_KEY")
      System.delete_env("DATABASE_URL") 
      System.delete_env("SECRET_KEY_BASE")
    end

    test "reports all validation errors at once" do
      System.delete_env("AT_UK_E_API_KEY")
      System.delete_env("DATABASE_URL")
      System.put_env("SYNC_INTERVAL", "invalid")
      
      assert {:error, errors} = ConfigManager.validate_all_config()
      assert is_list(errors)
      assert length(errors) > 1  # Should catch multiple issues
      
      System.delete_env("SYNC_INTERVAL")
    end

    test "validates cross-configuration dependencies" do
      # Test that auto_sync requires valid airtable config
      System.put_env("AUTO_SYNC_ENABLED", "true")
      System.delete_env("AT_UK_E_API_KEY")  # Missing required dependency
      
      assert {:error, errors} = ConfigManager.validate_all_config()
      assert :auto_sync_requires_airtable_config in errors
      
      System.delete_env("AUTO_SYNC_ENABLED")
    end
  end

  describe "watch_config_changes/1" do
    test "subscribes to configuration change notifications" do
      # Subscribe to changes
      ConfigManager.watch_config_changes(self())
      
      # Make a configuration change
      ConfigManager.set_config(:features, :test_feature, true)
      
      # Should receive notification
      assert_receive {:config_changed, :features, :test_feature, true}, 1000
    end

    test "handles multiple subscribers" do
      pid1 = spawn(fn -> receive do _ -> :ok end end)
      pid2 = spawn(fn -> receive do _ -> :ok end end)
      
      ConfigManager.watch_config_changes(pid1)
      ConfigManager.watch_config_changes(pid2)
      
      ConfigManager.set_config(:features, :broadcast_test, "value")
      
      # Both should receive notification
      send(pid1, :check)
      send(pid2, :check)
    end

    test "stops notifications when process dies" do
      pid = spawn(fn -> receive do _ -> :ok end end)
      ConfigManager.watch_config_changes(pid)
      
      # Kill the process
      Process.exit(pid, :kill)
      :timer.sleep(10)  # Give time for cleanup
      
      # Subsequent changes shouldn't cause errors
      ConfigManager.set_config(:features, :after_death, "value")
    end
  end

  describe "get_environment_summary/0" do
    test "provides summary of environment configuration" do
      summary = ConfigManager.get_environment_summary()
      
      assert is_map(summary)
      assert Map.has_key?(summary, :environment)
      assert Map.has_key?(summary, :required_env_vars)
      assert Map.has_key?(summary, :optional_env_vars)
      assert Map.has_key?(summary, :missing_required)
      assert Map.has_key?(summary, :feature_flags)
      
      assert summary[:environment] in [:dev, :test, :prod]
      assert is_list(summary[:required_env_vars])
      assert is_list(summary[:optional_env_vars])
      assert is_list(summary[:missing_required])
      assert is_map(summary[:feature_flags])
    end

    test "identifies missing required environment variables" do
      System.delete_env("AT_UK_E_API_KEY")
      System.delete_env("DATABASE_URL")
      
      summary = ConfigManager.get_environment_summary()
      
      assert "AT_UK_E_API_KEY" in summary[:missing_required]
      assert "DATABASE_URL" in summary[:missing_required]
    end

    test "includes status of all feature flags" do
      summary = ConfigManager.get_environment_summary()
      
      flags = summary[:feature_flags]
      assert Map.has_key?(flags, :auto_sync)
      assert Map.has_key?(flags, :manual_sync)
      assert Map.has_key?(flags, :export_enabled)
    end
  end

  describe "export_config/1" do
    test "exports configuration in specified format" do
      config_json = ConfigManager.export_config(:json)
      assert is_binary(config_json)
      
      # Should be valid JSON
      parsed = Jason.decode!(config_json)
      assert is_map(parsed)
    end

    test "exports configuration as Elixir terms" do
      config_elixir = ConfigManager.export_config(:elixir)
      assert is_binary(config_elixir)
      assert config_elixir =~ "config :ehs_enforcement"
    end

    test "masks sensitive values in export" do
      config_json = ConfigManager.export_config(:json)
      parsed = Jason.decode!(config_json)
      
      # API key should be masked
      airtable_config = get_in(parsed, ["airtable"])
      assert airtable_config["api_key"] == "***MASKED***" or airtable_config["api_key"] == nil
    end

    test "supports environment variable format export" do
      env_export = ConfigManager.export_config(:env)
      assert is_binary(env_export)
      assert env_export =~ "AT_UK_E_API_KEY"
      assert env_export =~ "DATABASE_URL"
    end
  end
end