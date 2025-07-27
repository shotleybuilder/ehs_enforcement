defmodule EhsEnforcement.Config.EnvironmentTest do
  use ExUnit.Case, async: true

  alias EhsEnforcement.Config.Environment

  describe "get_required_vars/0" do
    test "returns list of all required environment variables" do
      required = Environment.get_required_vars()
      
      assert is_list(required)
      
      # Extract just the names for easier testing
      required_names = Enum.map(required, & &1.name)
      assert "AT_UK_E_API_KEY" in required_names
      assert "DATABASE_URL" in required_names
      assert "SECRET_KEY_BASE" in required_names
    end

    test "includes descriptions for each required variable" do
      required = Environment.get_required_vars()
      
      # Should be list of maps with name and description
      Enum.each(required, fn var ->
        assert is_map(var)
        assert Map.has_key?(var, :name)
        assert Map.has_key?(var, :description)
        assert Map.has_key?(var, :example)
        assert is_binary(var[:name])
        assert is_binary(var[:description])
      end)
    end
  end

  describe "get_optional_vars/0" do
    test "returns list of all optional environment variables" do
      optional = Environment.get_optional_vars()
      
      assert is_list(optional)
      assert Enum.any?(optional, fn var -> var[:name] == "SYNC_INTERVAL" end)
      assert Enum.any?(optional, fn var -> var[:name] == "HSE_ENABLED" end)
      assert Enum.any?(optional, fn var -> var[:name] == "AUTO_SYNC_ENABLED" end)
    end

    test "includes default values for optional variables" do
      optional = Environment.get_optional_vars()
      
      sync_interval_var = Enum.find(optional, fn var -> var[:name] == "SYNC_INTERVAL" end)
      assert sync_interval_var[:default] == "60"
      
      hse_enabled_var = Enum.find(optional, fn var -> var[:name] == "HSE_ENABLED" end)
      assert hse_enabled_var[:default] == "true"
    end
  end

  describe "validate_var/2" do
    test "validates AT_UK_E_API_KEY format" do
      assert Environment.validate_var("AT_UK_E_API_KEY", "keyTestValidLength") == :ok
      assert {:error, :too_short} = Environment.validate_var("AT_UK_E_API_KEY", "short")
      assert {:error, :invalid_format} = Environment.validate_var("AT_UK_E_API_KEY", "")
    end

    test "validates DATABASE_URL format" do
      valid_url = "postgresql://user:pass@localhost:5432/ehs_enforcement"
      assert Environment.validate_var("DATABASE_URL", valid_url) == :ok
      
      assert {:error, :invalid_format} = Environment.validate_var("DATABASE_URL", "not_a_url")
      assert {:error, :invalid_format} = Environment.validate_var("DATABASE_URL", "http://not-postgres")
    end

    test "validates SECRET_KEY_BASE length" do
      valid_key = String.duplicate("a", 64)
      assert Environment.validate_var("SECRET_KEY_BASE", valid_key) == :ok
      
      short_key = String.duplicate("a", 10)
      assert {:error, :too_short} = Environment.validate_var("SECRET_KEY_BASE", short_key)
    end

    test "validates SYNC_INTERVAL is positive integer" do
      assert Environment.validate_var("SYNC_INTERVAL", "60") == :ok
      assert Environment.validate_var("SYNC_INTERVAL", "120") == :ok
      
      assert {:error, :not_integer} = Environment.validate_var("SYNC_INTERVAL", "not_number")
      assert {:error, :not_positive} = Environment.validate_var("SYNC_INTERVAL", "0")
      assert {:error, :not_positive} = Environment.validate_var("SYNC_INTERVAL", "-5")
    end

    test "validates boolean environment variables" do
      assert Environment.validate_var("HSE_ENABLED", "true") == :ok
      assert Environment.validate_var("HSE_ENABLED", "false") == :ok
      assert Environment.validate_var("HSE_ENABLED", "TRUE") == :ok
      assert Environment.validate_var("HSE_ENABLED", "False") == :ok
      
      assert {:error, :not_boolean} = Environment.validate_var("HSE_ENABLED", "maybe")
      assert {:error, :not_boolean} = Environment.validate_var("HSE_ENABLED", "1")
    end

    test "validates PHX_HOST format for production" do
      assert Environment.validate_var("PHX_HOST", "example.com") == :ok
      assert Environment.validate_var("PHX_HOST", "my-app.herokuapp.com") == :ok
      
      assert {:error, :invalid_host} = Environment.validate_var("PHX_HOST", "localhost")
      assert {:error, :invalid_host} = Environment.validate_var("PHX_HOST", "")
    end

    test "returns ok for unknown variables" do
      # Should not fail for unknown variables (future extensibility)
      assert Environment.validate_var("UNKNOWN_VAR", "value") == :ok
    end
  end

  describe "check_missing_required/0" do
    test "returns empty list when all required vars are present" do
      System.put_env("AT_UK_E_API_KEY", "test_key_12345")
      System.put_env("DATABASE_URL", "postgresql://user:pass@localhost/test_db")
      System.put_env("SECRET_KEY_BASE", String.duplicate("a", 64))
      
      missing = Environment.check_missing_required()
      assert missing == []
      
      # Clean up
      System.delete_env("AT_UK_E_API_KEY")
      System.delete_env("DATABASE_URL")
      System.delete_env("SECRET_KEY_BASE")
    end

    test "identifies missing required variables" do
      System.delete_env("AT_UK_E_API_KEY")
      System.delete_env("DATABASE_URL")
      
      missing = Environment.check_missing_required()
      assert "AT_UK_E_API_KEY" in missing
      assert "DATABASE_URL" in missing
    end

    test "includes validation errors for present but invalid variables" do
      System.put_env("AT_UK_E_API_KEY", "short")  # Invalid format
      System.put_env("DATABASE_URL", "postgresql://valid@localhost/db")
      System.put_env("SECRET_KEY_BASE", String.duplicate("a", 64))
      
      issues = Environment.check_missing_required()
      # Should include validation errors, not just missing vars
      assert length(issues) > 0
      
      System.delete_env("AT_UK_E_API_KEY")
      System.delete_env("DATABASE_URL")
      System.delete_env("SECRET_KEY_BASE")
    end
  end

  describe "get_environment_documentation/0" do
    test "generates comprehensive documentation for all environment variables" do
      docs = Environment.get_environment_documentation()
      
      assert is_binary(docs)
      assert docs =~ "# Environment Variables"
      assert docs =~ "## Required Variables"
      assert docs =~ "## Optional Variables"
      assert docs =~ "AT_UK_E_API_KEY"
      assert docs =~ "DATABASE_URL"
    end

    test "includes examples for each variable" do
      docs = Environment.get_environment_documentation()
      
      assert docs =~ "postgresql://username:password@localhost/ehs_enforcement"
      assert docs =~ "AT_UK_E_API_KEY="
      assert docs =~ "Default"
    end

    test "includes validation rules" do
      docs = Environment.get_environment_documentation()
      
      assert docs =~ "Minimum"
      assert docs =~ "Positive integer"
      assert docs =~ "true/false"
    end
  end

  describe "load_from_file/1" do
    test "loads environment variables from .env file" do
      # Create temporary .env file
      env_content = """
      AT_UK_E_API_KEY=test_key_from_file
      SYNC_INTERVAL=300
      HSE_ENABLED=false
      """
      
      File.write!("/tmp/test.env", env_content)
      
      # Load variables
      result = Environment.load_from_file("/tmp/test.env")
      assert result == :ok
      
      # Variables should be set
      assert System.get_env("AT_UK_E_API_KEY") == "test_key_from_file"
      assert System.get_env("SYNC_INTERVAL") == "300"
      assert System.get_env("HSE_ENABLED") == "false"
      
      # Clean up
      File.rm("/tmp/test.env")
      System.delete_env("AT_UK_E_API_KEY")
      System.delete_env("SYNC_INTERVAL")
      System.delete_env("HSE_ENABLED")
    end

    test "handles missing .env file gracefully" do
      result = Environment.load_from_file("/nonexistent/.env")
      assert {:error, :file_not_found} = result
    end

    test "validates loaded environment variables" do
      # Create .env with invalid values
      env_content = """
      AT_UK_E_API_KEY=short
      SYNC_INTERVAL=invalid
      """
      
      File.write!("/tmp/invalid.env", env_content)
      
      result = Environment.load_from_file("/tmp/invalid.env")
      assert {:error, validation_errors} = result
      assert is_list(validation_errors)
      
      File.rm("/tmp/invalid.env")
    end

    test "handles comments and empty lines in .env file" do
      env_content = """
      # Airtable configuration
      AT_UK_E_API_KEY=test_key_123
      
      # Sync settings
      SYNC_INTERVAL=120
      
      # Empty line above should be ignored
      """
      
      File.write!("/tmp/commented.env", env_content)
      
      result = Environment.load_from_file("/tmp/commented.env")
      assert result == :ok
      
      assert System.get_env("AT_UK_E_API_KEY") == "test_key_123"
      assert System.get_env("SYNC_INTERVAL") == "120"
      
      File.rm("/tmp/commented.env")
      System.delete_env("AT_UK_E_API_KEY")
      System.delete_env("SYNC_INTERVAL")
    end
  end

  describe "export_template/1" do
    test "generates .env template with all variables" do
      template = Environment.export_template(:env)
      
      assert is_binary(template)
      assert template =~ "AT_UK_E_API_KEY="
      assert template =~ "DATABASE_URL="
      assert template =~ "SYNC_INTERVAL=60"  # Should include defaults
      assert template =~ "HSE_ENABLED=true"
    end

    test "generates Docker Compose environment section" do
      template = Environment.export_template(:docker_compose)
      
      assert is_binary(template)
      assert template =~ "environment:"
      assert template =~ "- AT_UK_E_API_KEY=${AT_UK_E_API_KEY}"
      assert template =~ "- DATABASE_URL=${DATABASE_URL}"
    end

    test "generates Kubernetes ConfigMap template" do
      template = Environment.export_template(:kubernetes)
      
      assert is_binary(template)
      assert template =~ "apiVersion: v1"
      assert template =~ "kind: ConfigMap"
      assert template =~ "SYNC_INTERVAL: \"60\""
    end

    test "includes documentation comments in templates" do
      template = Environment.export_template(:env)
      
      assert template =~ "# Required: Airtable API key"
      assert template =~ "# Optional: Sync interval in minutes"
      assert template =~ "# Default: 60"
    end
  end

  describe "detect_environment/0" do
    test "detects test environment correctly" do
      env = Environment.detect_environment()
      assert env == :test
    end

    test "detects environment from MIX_ENV" do
      original_env = System.get_env("MIX_ENV")
      
      System.put_env("MIX_ENV", "prod")
      assert Environment.detect_environment() == :prod
      
      System.put_env("MIX_ENV", "dev")
      assert Environment.detect_environment() == :dev
      
      # Restore original
      if original_env do
        System.put_env("MIX_ENV", original_env)
      else
        System.delete_env("MIX_ENV")
      end
    end

    test "has different validation rules per environment" do
      # In test environment, some validations might be more lenient
      test_rules = Environment.get_validation_rules(:test)
      prod_rules = Environment.get_validation_rules(:prod)
      
      assert is_map(test_rules)
      assert is_map(prod_rules)
      
      # Production should require PHX_HOST
      assert Map.has_key?(prod_rules, "PHX_HOST")
      assert prod_rules["PHX_HOST"][:required] == true
      
      # Test environment should not require PHX_HOST
      if Map.has_key?(test_rules, "PHX_HOST") do
        assert test_rules["PHX_HOST"][:required] == false
      end
    end
  end
end