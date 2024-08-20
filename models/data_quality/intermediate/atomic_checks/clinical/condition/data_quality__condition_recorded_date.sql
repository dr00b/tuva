{{ config(
    enabled = var('clinical_enabled', False)
) }}

SELECT
    m.data_source
    ,coalesce(m.recorded_date,cast('1900-01-01' as date)) as source_date
    ,'CONDITION' AS table_name
    ,'Condition ID' as drill_down_key
    , coalesce(condition_id, 'NULL') AS drill_down_value
    ,'RECORDED_DATE' AS field_name
    ,CASE
        when m.recorded_date > cast(substring('{{ var('tuva_last_run') }}',1,10) as date) then 'invalid'
        when m.recorded_date <= cast('1901-01-01' as date) then 'invalid'
        when m.recorded_date < m.onset_date then 'invalid'
        when m.recorded_date is null then 'null'
        else 'valid'
    end as bucket_name
    ,case
        when m.recorded_date > cast(substring('{{ var('tuva_last_run') }}',1,10) as date) then 'future'
        when m.recorded_date <= cast('1901-01-01' as date) then 'too old'
        WHEN m.recorded_date < m.onset_date THEN 'Recorded date before onset date'
        else null
    end as invalid_reason
    ,cast(recorded_date as {{ dbt.type_string() }}) as field_value
    , '{{ var('tuva_last_run')}}' as tuva_last_run
from {{ ref('condition')}} m
