defmodule EhsEnforcement.Enforcement.Agency do
  @moduledoc """
  Represents an enforcement agency (HSE, ONR, ORR, EA, etc.)
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "agencies"
    repo EhsEnforcement.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :code, :atom do
      allow_nil? false
      constraints [one_of: [:hse, :onr, :orr, :ea]]
    end
    
    attribute :name, :string, allow_nil?: false
    attribute :base_url, :string
    attribute :active, :boolean, default: true
    
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :cases, EhsEnforcement.Enforcement.Case
    has_many :notices, EhsEnforcement.Enforcement.Notice
  end

  identities do
    identity :unique_code, [:code]
  end

  actions do
    defaults [:read, :destroy]
    
    create :create do
      primary? true
      accept [:code, :name, :base_url, :active]
    end
    
    update :update do
      primary? true
      accept [:name, :base_url, :active]
    end
  end

  aggregates do
    count :total_cases, :cases
    sum :total_fines, :cases, :offence_fine
    max :last_sync, :cases, :last_synced_at
  end

  code_interface do
    define :create, args: [:code, :name]
    define :update
  end
end