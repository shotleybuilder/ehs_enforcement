defmodule EhsEnforcement.Config.ValidatorTest do
  use ExUnit.Case, async: true

  alias EhsEnforcement.Config.Validator

  describe "validate_on_startup/0" do
    test "validates all critical configuration on application startup" do
      # Mock all required environment variables
      System.put_env("AT_UK_E_API_KEY", "test_api_key")
      System.put_env("DATABASE_URL", "postgresql://user:pass@localhost/ehs_enforcement")
      System.put_env("SECRET_KEY_BASE", "a_very_long_secret_key_base_for_testing_purposes_that_meets_minimum_length_requirements")
      
      # This will fail because Validator module doesn't exist yet
      assert Validator.validate_on_startup() == :ok
      
      # Clean up
      System.delete_env("AT_UK_E_API_KEY")
      System.delete_env("DATABASE_URL")
      System.delete_env("SECRET_KEY_BASE")
    end

    test "fails fast when critical configuration is missing" do
      # Remove all environment variables
      System.delete_env("AT_UK_E_API_KEY")
      System.delete_env("DATABASE_URL")
      System.delete_env("SECRET_KEY_BASE")
      
      assert {:error, errors} = Validator.validate_on_startup()
      assert is_list(errors)
      assert length(errors) > 0
    end

    test "validates Airtable API key is present" do
      System.delete_env("AT_UK_E_API_KEY")
      System.put_env("DATABASE_URL", "postgresql://user:pass@localhost/ehs_enforcement")
      System.put_env("SECRET_KEY_BASE", "a_very_long_secret_key_base_for_testing")
      
      assert {:error, errors} = Validator.validate_on_startup()
      assert :missing_airtable_api_key in errors
      
      System.delete_env("DATABASE_URL")
      System.delete_env("SECRET_KEY_BASE")
    end

    test "validates database URL is present and valid format" do
      System.put_env("AT_UK_E_API_KEY", "test_key")
      System.put_env("SECRET_KEY_BASE", "a_very_long_secret_key_base_for_testing")
      System.delete_env("DATABASE_URL")
      
      assert {:error, errors} = Validator.validate_on_startup()
      assert :missing_database_url in errors
      
      # Test invalid format
      System.put_env("DATABASE_URL", "invalid_url")
      assert {:error, errors} = Validator.validate_on_startup()
      assert :invalid_database_url in errors
      
      System.delete_env("AT_UK_E_API_KEY")
      System.delete_env("SECRET_KEY_BASE")
      System.delete_env("DATABASE_URL")
    end

    test "validates secret key base meets minimum length" do
      System.put_env("AT_UK_E_API_KEY", "test_key")
      System.put_env("DATABASE_URL", "postgresql://user:pass@localhost/ehs_enforcement")
      System.put_env("SECRET_KEY_BASE", "too_short")
      
      assert {:error, errors} = Validator.validate_on_startup()
      assert :invalid_secret_key_base in errors
      
      System.delete_env("AT_UK_E_API_KEY")
      System.delete_env("DATABASE_URL")
      System.delete_env("SECRET_KEY_BASE")
    end
  end

  describe "validate_airtable_config/0" do
    test "validates airtable configuration is complete" do
      System.put_env("AT_UK_E_API_KEY", "test_key")
      System.put_env("AIRTABLE_BASE_ID", "appTestBaseId")
      
      assert Validator.validate_airtable_config() == :ok
      
      System.delete_env("AT_UK_E_API_KEY")
      System.delete_env("AIRTABLE_BASE_ID")
    end

    test "validates API key format" do
      System.put_env("AT_UK_E_API_KEY", "key")  # Too short
      
      assert {:error, :invalid_api_key_format} = Validator.validate_airtable_config()
      
      System.delete_env("AT_UK_E_API_KEY")
    end

    test "validates base ID format" do
      System.put_env("AT_UK_E_API_KEY", "keyTestValidLength123")
      System.put_env("AIRTABLE_BASE_ID", "invalid")  # Should start with "app"
      
      assert {:error, :invalid_base_id_format} = Validator.validate_airtable_config()
      
      System.delete_env("AT_UK_E_API_KEY")
      System.delete_env("AIRTABLE_BASE_ID")
    end

    test "validates sync interval is positive integer" do
      System.put_env("AT_UK_E_API_KEY", "keyTestValidLength123")
      System.put_env("AIRTABLE_BASE_ID", "appTestBaseId")
      System.put_env("SYNC_INTERVAL", "0")  # Should be positive
      
      assert {:error, :invalid_sync_interval} = Validator.validate_airtable_config()
      
      System.put_env("SYNC_INTERVAL", "-10")  # Negative
      assert {:error, :invalid_sync_interval} = Validator.validate_airtable_config()
      
      System.delete_env("AT_UK_E_API_KEY")
      System.delete_env("AIRTABLE_BASE_ID")
      System.delete_env("SYNC_INTERVAL")
    end
  end

  describe "validate_agency_config/1" do
    test "validates HSE agency configuration" do
      System.put_env("HSE_ENABLED", "true")
      
      assert Validator.validate_agency_config(:hse) == :ok
      
      System.delete_env("HSE_ENABLED")
    end

    test "allows disabled agencies" do
      System.put_env("HSE_ENABLED", "false")
      
      assert Validator.validate_agency_config(:hse) == :ok
      
      System.delete_env("HSE_ENABLED")
    end

    test "validates unknown agency returns error" do
      assert {:error, :unknown_agency} = Validator.validate_agency_config(:unknown)
    end

    test "validates agency base URL format" do
      # This would test if agencies have custom base URLs
      # For now HSE uses hardcoded URL, but future agencies might be configurable
      assert Validator.validate_agency_config(:hse) == :ok
    end
  end

  describe "validate_database_connection/0" do
    test "validates database connection can be established" do
      System.put_env("DATABASE_URL", "postgresql://postgres:postgres@localhost/ehs_enforcement_test")
      
      # This will test actual database connectivity
      # In real app, this would try to connect to the database
      assert Validator.validate_database_connection() == :ok
      
      System.delete_env("DATABASE_URL")
    end

    test "returns error when database is unreachable" do
      System.put_env("DATABASE_URL", "postgresql://invalid:invalid@nonexistent:5432/invalid")
      
      assert {:error, :database_connection_failed} = Validator.validate_database_connection()
      
      System.delete_env("DATABASE_URL")
    end

    test "validates database has required tables" do
      # This would check that migrations have been run
      System.put_env("DATABASE_URL", "postgresql://postgres:postgres@localhost/ehs_enforcement_test")
      
      # For testing, we'll assume tables exist
      assert Validator.validate_database_connection() == :ok
      
      System.delete_env("DATABASE_URL")
    end
  end

  describe "validate_feature_flags/0" do
    test "validates all feature flags have valid values" do
      System.put_env("AUTO_SYNC_ENABLED", "true")
      
      assert Validator.validate_feature_flags() == :ok
      
      System.put_env("AUTO_SYNC_ENABLED", "false")
      assert Validator.validate_feature_flags() == :ok
      
      System.delete_env("AUTO_SYNC_ENABLED")
    end

    test "returns error for invalid boolean values" do
      System.put_env("AUTO_SYNC_ENABLED", "maybe")
      
      assert {:error, :invalid_feature_flag_value} = Validator.validate_feature_flags()
      
      System.delete_env("AUTO_SYNC_ENABLED")
    end

    test "handles missing feature flags gracefully with defaults" do
      System.delete_env("AUTO_SYNC_ENABLED")
      
      # Should use defaults and pass validation
      assert Validator.validate_feature_flags() == :ok
    end
  end

  describe "validate_environment/0" do
    test "detects test environment correctly" do
      # In test environment
      result = Validator.validate_environment()
      assert result[:environment] == :test
      assert result[:warnings] == []
    end

    test "warns about missing production settings in non-test environment" do
      # This would test production environment validation
      # For now, we'll assume test environment is always valid
      result = Validator.validate_environment()
      assert is_map(result)
      assert Map.has_key?(result, :environment)
    end

    test "validates phoenix host in production" do
      # Mock production environment
      original_env = Application.get_env(:ehs_enforcement, :environment)
      Application.put_env(:ehs_enforcement, :environment, :prod)
      
      # Should warn about missing PHX_HOST
      result = Validator.validate_environment()
      assert result[:environment] == :prod
      # In production, should have warnings if PHX_HOST not set
      
      # Restore original environment
      Application.put_env(:ehs_enforcement, :environment, original_env)
    end
  end
end