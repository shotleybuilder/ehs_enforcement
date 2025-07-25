defmodule EhsEnforcement.Enforcement.Offender do
  @moduledoc """
  Represents a company or individual subject to enforcement action.
  Normalized to eliminate duplication between cases and notices.
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Enforcement,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "offenders"
    repo EhsEnforcement.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :name, :string, allow_nil?: false
    attribute :local_authority, :string
    attribute :postcode, :string
    attribute :main_activity, :string
    attribute :business_type, :atom do
      constraints [one_of: [:limited_company, :individual, :partnership, :plc, :other]]
    end
    attribute :industry, :string
    
    # Aggregated statistics
    attribute :first_seen_date, :date
    attribute :last_seen_date, :date
    attribute :total_cases, :integer, default: 0
    attribute :total_notices, :integer, default: 0
    attribute :total_fines, :decimal, default: 0
    
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :cases, EhsEnforcement.Enforcement.Case
    has_many :notices, EhsEnforcement.Enforcement.Notice
  end

  identities do
    identity :unique_name_postcode, [:name, :postcode]
  end

  actions do
    defaults [:read]
    
    create :create do
      primary? true
      accept [:name, :local_authority, :postcode, :main_activity, :business_type, :industry]
      
      change fn changeset, _context ->
        case Ash.Changeset.get_attribute(changeset, :name) do
          nil -> changeset
          name -> 
            normalized_name = normalize_company_name(name)
            Ash.Changeset.force_change_attribute(changeset, :name, normalized_name)
        end
      end
    end
    
    update :update do
      primary? true
      accept [:local_authority, :main_activity, :business_type, :industry]
    end
    
    update :update_statistics do
      require_atomic? false
      accept []
      argument :fine_amount, :decimal
      
      change fn changeset, _context ->
        fine_amount = Ash.Changeset.get_argument(changeset, :fine_amount) || Decimal.new("0")
        
        # Get current values from the database record, defaulting to 0 if nil
        current_cases = changeset.data.total_cases || 0
        current_notices = changeset.data.total_notices || 0  
        current_fines = changeset.data.total_fines || Decimal.new("0")
        
        new_fines = Decimal.add(current_fines, fine_amount)
        
        # Set new values by incrementing
        changeset
        |> Ash.Changeset.force_change_attribute(:total_cases, current_cases + 1)
        |> Ash.Changeset.force_change_attribute(:total_notices, current_notices + 1)
        |> Ash.Changeset.force_change_attribute(:total_fines, new_fines)
      end
    end
    
    read :search do
      argument :query, :string, allow_nil?: false
      
      filter expr(
        ilike(name, "%" <> ^arg(:query) <> "%") or
        ilike(local_authority, "%" <> ^arg(:query) <> "%") or
        ilike(postcode, "%" <> ^arg(:query) <> "%")
      )
    end
  end

  calculations do
    calculate :enforcement_count, :integer do
      calculation expr(total_cases + total_notices)
    end
  end

  code_interface do
    define :create, args: [:name]
    define :update_statistics
  end

  defp normalize_company_name(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/\s+(limited|ltd\.?)$/i, " limited")
    |> String.replace(~r/\s+(plc|p\.l\.c\.?)$/i, " plc")
    |> String.trim()
  end

  defp normalize_company_name(name), do: name
end