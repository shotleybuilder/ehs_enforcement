defmodule EhsEnforcement.Sync.SyncLog do
  @moduledoc """
  Tracks synchronization operations and their results.
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Sync,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "sync_logs"
    repo EhsEnforcement.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :sync_type, :atom do
      constraints [one_of: [:cases, :notices]]
    end
    
    attribute :status, :atom do
      constraints [one_of: [:started, :completed, :failed]]
    end
    
    attribute :records_synced, :integer, default: 0
    attribute :error_message, :string
    attribute :started_at, :utc_datetime
    attribute :completed_at, :utc_datetime
    
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :agency, EhsEnforcement.Enforcement.Agency do
      allow_nil? false
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  code_interface do
    define :create
  end
end