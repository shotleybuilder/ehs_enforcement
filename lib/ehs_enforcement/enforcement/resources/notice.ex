defmodule EhsEnforcement.Enforcement.Notice do
  @moduledoc """
  Represents an enforcement notice issued to an offender.
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "notices"
    repo EhsEnforcement.Repo
    
    identity_wheres_to_sql(unique_airtable_id: "airtable_id IS NOT NULL")
  end

  attributes do
    uuid_primary_key :id
    
    attribute :airtable_id, :string
    attribute :regulator_id, :string
    attribute :regulator_ref_number, :string
    attribute :notice_type, :string
    attribute :notice_date, :date
    attribute :operative_date, :date
    attribute :compliance_date, :date
    attribute :notice_body, :string
    attribute :last_synced_at, :utc_datetime
    
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :agency, EhsEnforcement.Enforcement.Agency do
      allow_nil? false
    end
    
    belongs_to :offender, EhsEnforcement.Enforcement.Offender do
      allow_nil? false
    end
  end

  identities do
    identity :unique_airtable_id, [:airtable_id], where: expr(not is_nil(airtable_id))
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end

  code_interface do
    define :create
  end
end