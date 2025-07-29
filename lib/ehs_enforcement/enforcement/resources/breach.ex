defmodule EhsEnforcement.Enforcement.Breach do
  @moduledoc """
  Represents a specific breach of legislation associated with a case.
  Normalized from the breaches text in cases.
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "breaches"
    repo EhsEnforcement.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :breach_description, :string
    attribute :legislation_reference, :string
    attribute :legislation_type, :atom do
      constraints [one_of: [:act, :regulation, :acop]]
    end
    
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :case, EhsEnforcement.Enforcement.Case do
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :update, :destroy]
    
    create :create do
      primary? true
      accept [:breach_description, :legislation_reference, :legislation_type, :case_id]
    end
  end

  code_interface do
    define :create
  end
end