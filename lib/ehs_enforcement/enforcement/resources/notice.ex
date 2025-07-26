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
    attribute :notice_date, :date
    attribute :operative_date, :date
    attribute :compliance_date, :date
    attribute :notice_body, :string
    attribute :offence_action_type, :string
    attribute :offence_action_date, :date
    attribute :offence_breaches, :string
    attribute :url, :string
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
    defaults [:read, :update, :destroy]
    
    create :create do
      accept [:airtable_id, :regulator_id, :regulator_ref_number,
              :notice_date, :operative_date, :compliance_date, :notice_body,
              :offence_action_type, :offence_action_date, :offence_breaches, :url,
              :last_synced_at, :agency_id, :offender_id]
    end
  end

  code_interface do
    define :create
  end
end