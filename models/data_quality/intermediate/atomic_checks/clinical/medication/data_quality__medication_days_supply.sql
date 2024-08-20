{{ config(
    enabled = var('clinical_enabled', False)
) }}


SELECT
      m.data_source
    , coalesce(m.dispensing_date,cast('1900-01-01' as date)) as source_date
    , 'MEDICATION' AS table_name
    , 'Medication ID' as drill_down_key
    , coalesce(medication_id, 'NULL') AS drill_down_value
    , 'DAYS_SUPPLY' AS field_name
    , case when m.days_supply is not null then 'valid' else 'null' end as bucket_name
    , cast(null as {{ dbt.type_string() }}) as invalid_reason
    , cast(days_supply as {{ dbt.type_string() }}) as field_value
    , '{{ var('tuva_last_run')}}' as tuva_last_run
from {{ ref('medication')}} m
