defmodule EhsEnforcement.Enforcement.Case do
  @moduledoc """
  Represents an enforcement case (court case) against an offender.
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "cases"
    repo EhsEnforcement.Repo
    
    identity_wheres_to_sql(unique_airtable_id: "airtable_id IS NOT NULL")
  end

  attributes do
    uuid_primary_key :id
    
    attribute :airtable_id, :string
    attribute :regulator_id, :string
    attribute :offence_result, :string
    attribute :offence_fine, :decimal
    attribute :offence_costs, :decimal
    attribute :offence_action_date, :date
    attribute :offence_hearing_date, :date
    attribute :offence_breaches, :string
    attribute :offence_breaches_clean, :string
    attribute :regulator_function, :string
    attribute :regulator_url, :string
    attribute :related_cases, :string
    attribute :offence_action_type, :string
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
    
    has_many :breaches, EhsEnforcement.Enforcement.Breach
  end

  identities do
    identity :unique_airtable_id, [:airtable_id], where: expr(not is_nil(airtable_id))
  end

  actions do
    defaults [:read, :destroy]
    
    create :create do
      primary? true
      accept [:airtable_id, :regulator_id, :offence_result, :offence_fine, :offence_costs,
              :offence_action_date, :offence_hearing_date, :offence_breaches, 
              :offence_breaches_clean, :regulator_function, :regulator_url, :related_cases,
              :offence_action_type, :url, :last_synced_at]
      
      argument :agency_code, :atom
      argument :offender_attrs, :map
      argument :agency_id, :uuid
      argument :offender_id, :uuid
      
      change fn changeset, context ->
        cond do
          # Direct IDs provided
          Ash.Changeset.get_argument(changeset, :agency_id) && 
          Ash.Changeset.get_argument(changeset, :offender_id) ->
            agency_id = Ash.Changeset.get_argument(changeset, :agency_id)
            offender_id = Ash.Changeset.get_argument(changeset, :offender_id)
            
            changeset
            |> Ash.Changeset.force_change_attribute(:agency_id, agency_id)
            |> Ash.Changeset.force_change_attribute(:offender_id, offender_id)
          
          # Code and attrs provided
          Ash.Changeset.get_argument(changeset, :agency_code) &&
          Ash.Changeset.get_argument(changeset, :offender_attrs) ->
            agency_code = Ash.Changeset.get_argument(changeset, :agency_code)
            offender_attrs = Ash.Changeset.get_argument(changeset, :offender_attrs)
            
            # Look up agency by code
            case EhsEnforcement.Enforcement.get_agency_by_code(agency_code) do
              {:ok, agency} when not is_nil(agency) ->
                # Find or create offender
                case EhsEnforcement.Sync.OffenderMatcher.find_or_create_offender(offender_attrs) do
                  {:ok, offender} ->
                    changeset
                    |> Ash.Changeset.force_change_attribute(:agency_id, agency.id)
                    |> Ash.Changeset.force_change_attribute(:offender_id, offender.id)
                  
                  {:error, _} -> 
                    Ash.Changeset.add_error(changeset, "Failed to create offender")
                end
              
              {:ok, nil} ->
                Ash.Changeset.add_error(changeset, "Agency not found: #{agency_code}")
              
              {:error, _} ->
                Ash.Changeset.add_error(changeset, "Failed to lookup agency: #{agency_code}")
            end
          
          true -> changeset
        end
      end
    end
    
    update :sync do
      accept [:offence_result, :offence_fine, :offence_costs, :offence_hearing_date]
      
      change set_attribute(:last_synced_at, &DateTime.utc_now/0)
    end
    
    read :by_date_range do
      argument :from_date, :date, allow_nil?: false
      argument :to_date, :date, allow_nil?: false
      
      filter expr(
        offence_action_date >= ^arg(:from_date) and 
        offence_action_date <= ^arg(:to_date)
      )
    end
  end

  calculations do
    calculate :total_penalty, :decimal do
      calculation expr((offence_fine || 0) + (offence_costs || 0))
    end
  end

  code_interface do
    define :create
    define :sync
  end
end