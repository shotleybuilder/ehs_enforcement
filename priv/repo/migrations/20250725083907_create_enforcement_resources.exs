defmodule EhsEnforcement.Repo.Migrations.CreateEnforcementResources do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    create table(:sync_logs, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :sync_type, :text
      add :status, :text
      add :records_synced, :bigint, default: 0
      add :error_message, :text
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :agency_id, :uuid, null: false
    end

    create table(:offenders, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :name, :text, null: false
      add :local_authority, :text
      add :postcode, :text
      add :main_activity, :text
      add :business_type, :text
      add :industry, :text
      add :first_seen_date, :date
      add :last_seen_date, :date
      add :total_cases, :bigint, default: 0
      add :total_notices, :bigint, default: 0
      add :total_fines, :decimal, default: "0"

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:offenders, [:name, :postcode],
             name: "offenders_unique_name_postcode_index"
           )

    create table(:notices, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :airtable_id, :text
      add :regulator_id, :text
      add :regulator_ref_number, :text
      add :notice_type, :text
      add :notice_date, :date
      add :operative_date, :date
      add :compliance_date, :date
      add :notice_body, :text
      add :last_synced_at, :utc_datetime

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :agency_id, :uuid, null: false
      add :offender_id, :uuid, null: false
    end

    create table(:cases, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :airtable_id, :text
      add :regulator_id, :text
      add :offence_result, :text
      add :offence_fine, :decimal
      add :offence_costs, :decimal
      add :offence_action_date, :date
      add :offence_hearing_date, :date
      add :offence_breaches, :text
      add :offence_breaches_clean, :text
      add :regulator_function, :text
      add :regulator_url, :text
      add :related_cases, :text
      add :last_synced_at, :utc_datetime

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :agency_id, :uuid, null: false
      add :offender_id, :uuid, null: false
    end

    create table(:breaches, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :breach_description, :text
      add :legislation_reference, :text
      add :legislation_type, :text

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :case_id,
          references(:cases,
            column: :id,
            name: "breaches_case_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false
    end

    create table(:agencies, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
    end

    alter table(:sync_logs) do
      modify :agency_id,
             references(:agencies,
               column: :id,
               name: "sync_logs_agency_id_fkey",
               type: :uuid,
               prefix: "public"
             )
    end

    alter table(:notices) do
      modify :agency_id,
             references(:agencies,
               column: :id,
               name: "notices_agency_id_fkey",
               type: :uuid,
               prefix: "public"
             )

      modify :offender_id,
             references(:offenders,
               column: :id,
               name: "notices_offender_id_fkey",
               type: :uuid,
               prefix: "public"
             )
    end

    create unique_index(:notices, [:airtable_id],
             name: "notices_unique_airtable_id_index",
             where: "(airtable_id IS NOT NULL)"
           )

    alter table(:cases) do
      modify :agency_id,
             references(:agencies,
               column: :id,
               name: "cases_agency_id_fkey",
               type: :uuid,
               prefix: "public"
             )

      modify :offender_id,
             references(:offenders,
               column: :id,
               name: "cases_offender_id_fkey",
               type: :uuid,
               prefix: "public"
             )
    end

    create unique_index(:cases, [:airtable_id],
             name: "cases_unique_airtable_id_index",
             where: "(airtable_id IS NOT NULL)"
           )

    alter table(:agencies) do
      add :code, :text, null: false
      add :name, :text, null: false
      add :base_url, :text
      add :active, :boolean, default: true

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:agencies, [:code], name: "agencies_unique_code_index")
  end

  def down do
    drop_if_exists unique_index(:agencies, [:code], name: "agencies_unique_code_index")

    alter table(:agencies) do
      remove :updated_at
      remove :inserted_at
      remove :active
      remove :base_url
      remove :name
      remove :code
    end

    drop_if_exists unique_index(:cases, [:airtable_id], name: "cases_unique_airtable_id_index")

    drop constraint(:cases, "cases_agency_id_fkey")

    drop constraint(:cases, "cases_offender_id_fkey")

    alter table(:cases) do
      modify :offender_id, :uuid
      modify :agency_id, :uuid
    end

    drop_if_exists unique_index(:notices, [:airtable_id],
                     name: "notices_unique_airtable_id_index"
                   )

    drop constraint(:notices, "notices_agency_id_fkey")

    drop constraint(:notices, "notices_offender_id_fkey")

    alter table(:notices) do
      modify :offender_id, :uuid
      modify :agency_id, :uuid
    end

    drop constraint(:sync_logs, "sync_logs_agency_id_fkey")

    alter table(:sync_logs) do
      modify :agency_id, :uuid
    end

    drop table(:agencies)

    drop constraint(:breaches, "breaches_case_id_fkey")

    drop table(:breaches)

    drop table(:cases)

    drop table(:notices)

    drop_if_exists unique_index(:offenders, [:name, :postcode],
                     name: "offenders_unique_name_postcode_index"
                   )

    drop table(:offenders)

    drop table(:sync_logs)
  end
end
