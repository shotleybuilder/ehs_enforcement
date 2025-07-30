defmodule EhsEnforcement.Accounts.User do
  @moduledoc """
  User resource with GitHub OAuth authentication and admin privilege management.
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer]
  
  postgres do
    table "users"
    repo EhsEnforcement.Repo
  end
  
  attributes do
    uuid_primary_key :id
    
    # GitHub OAuth fields
    attribute :github_id, :string, allow_nil?: false
    attribute :github_login, :string, allow_nil?: false
    attribute :email, :ci_string, allow_nil?: true
    attribute :name, :string, allow_nil?: true
    attribute :avatar_url, :string, allow_nil?: true
    attribute :github_url, :string, allow_nil?: true
    
    # Admin privilege management
    attribute :is_admin, :boolean, default: false
    attribute :admin_checked_at, :utc_datetime_usec, allow_nil?: true
    attribute :last_login_at, :utc_datetime_usec, allow_nil?: true
    
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
  
  authentication do
    strategies do
      oauth2 :github do
        client_id fn _, _ -> get_oauth_config(:client_id) end
        client_secret fn _, _ -> get_oauth_config(:client_secret) end
        redirect_uri fn _, _ -> get_oauth_config(:redirect_uri) end
        base_url "https://github.com"
        authorize_url "https://github.com/login/oauth/authorize"
        token_url "https://github.com/login/oauth/access_token"
        user_url "https://api.github.com/user"
        authorization_params scope: "read:user,user:email"
        auth_method :client_secret_post
        
        identity_resource EhsEnforcement.Accounts.User
        identity_relationship_name :user
        identity_relationship_user_id_attribute :github_id
      end
    end
    
    tokens do
      enabled? true
      require_token_presence_for_authentication? true
      token_resource EhsEnforcement.Accounts.Token
      signing_secret fn _, _ -> get_token_signing_secret() end
    end
    
  end
  
  identities do
    identity :unique_github_id, [:github_id]
    identity :unique_github_login, [:github_login]
  end
  
  actions do
    defaults [:read, :destroy]
    
    create :create do
      primary? true
      accept [:github_id, :github_login, :email, :name, :avatar_url, :github_url]
    end
    
    create :register_with_github do
      upsert? true
      upsert_identity :unique_github_id
      argument :user_info, :map, allow_nil?: false
      argument :oauth_tokens, :map, allow_nil?: false
      accept [:github_id, :github_login, :email, :name, :avatar_url, :github_url]
      
      change AshAuthentication.GenerateTokenChange
      change {AshAuthentication.Strategy.OAuth2.IdentityChange, strategy: :github}
      
      change fn changeset, _context ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info)
        
        changeset
        |> Ash.Changeset.change_attribute(:github_id, to_string(user_info["id"]))
        |> Ash.Changeset.change_attribute(:github_login, user_info["login"])
        |> Ash.Changeset.change_attribute(:email, user_info["email"])
        |> Ash.Changeset.change_attribute(:name, user_info["name"])
        |> Ash.Changeset.change_attribute(:avatar_url, user_info["avatar_url"])
        |> Ash.Changeset.change_attribute(:github_url, user_info["html_url"])
        |> Ash.Changeset.change_attribute(:last_login_at, DateTime.utc_now())
      end
    end
    
    update :update do
      primary? true
      accept [:email, :name, :avatar_url, :github_url, :last_login_at]
    end
    
    update :update_admin_status do
      require_atomic? false
      accept [:is_admin, :admin_checked_at]
      
      change fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :admin_checked_at, DateTime.utc_now())
      end
    end
    
    read :by_github_id do
      argument :github_id, :string, allow_nil?: false
      filter expr(github_id == ^arg(:github_id))
    end
    
    read :by_github_login do
      argument :github_login, :string, allow_nil?: false
      filter expr(github_login == ^arg(:github_login))
    end
    
    read :admins do
      filter expr(is_admin == true)
    end
  end
  
  policies do
    # Default policy - users can read their own data
    policy always() do
      authorize_if always()
    end
    
    # Admin users can read all user data
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:is_admin, true)
    end
    
    # Users can update their own non-admin fields
    policy action_type(:update) do
      authorize_if expr(id == ^actor(:id))
      forbid_if changing_attributes([:is_admin, :admin_checked_at])
    end
    
    # Only system can update admin status
    policy action(:update_admin_status) do
      authorize_if always()
    end
    
    # Admin users can destroy any user
    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:is_admin, true)
    end
  end
  
  aggregates do
    count :login_count, [], filter: expr(not is_nil(last_login_at))
  end
  
  calculations do
    calculate :admin_status_fresh?, :boolean, expr(
      is_nil(admin_checked_at) or 
      fragment("? > (? + interval '1 hour')", now(), admin_checked_at)
    )
    
    calculate :display_name, :string, expr(
      cond do
        not is_nil(name) -> name
        true -> github_login
      end
    )
  end
  
  code_interface do
    define :create, args: [:github_id, :github_login]
    define :update
    define :update_admin_status, args: [:is_admin]
    define :by_github_id, args: [:github_id]
    define :by_github_login, args: [:github_login]
    define :admins
  end
  
  # Configuration helper functions
  
  defp get_oauth_config(:client_id), do: Application.get_env(:ehs_enforcement, :github_oauth)[:client_id]
  defp get_oauth_config(:client_secret), do: Application.get_env(:ehs_enforcement, :github_oauth)[:client_secret]
  defp get_oauth_config(:redirect_uri), do: Application.get_env(:ehs_enforcement, :github_oauth)[:redirect_uri]
  
  defp get_token_signing_secret do
    Application.get_env(:ehs_enforcement, :token_signing_secret) || 
      raise "TOKEN_SIGNING_SECRET environment variable is required"
  end
end