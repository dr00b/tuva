{{ config(
    enabled = var('claims_enabled', False)
) }}

with tuva_last_run as(

    select cast(substring('{{ var('tuva_last_run') }}',1,10) as date) as tuva_last_run

)

SELECT
      m.data_source
    , coalesce(cast(m.claim_start_date as {{ dbt.type_string() }}),cast('1900-01-01' as {{ dbt.type_string() }})) as source_date
    , 'MEDICAL_CLAIM' AS table_name
    , 'Claim ID | Claim Line Number' AS drill_down_key
    , {{ dbt.concat(["coalesce(cast(m.claim_id as " ~ dbt.type_string() ~ "), 'null')",
                    "'|'",
                    "coalesce(cast(m.claim_line_number as " ~ dbt.type_string() ~ "), 'null')"]) }} as drill_down_value
    , m.claim_type as claim_type
    , 'CLAIM_LINE_END_DATE' AS field_name
    , case
        when m.claim_line_end_date > tuva_last_run then 'invalid'
        when m.claim_line_end_date < {{ dbt.dateadd(datepart="year", interval=-10, from_date_or_timestamp="cte.tuva_last_run") }} then 'invalid'
        when m.claim_line_end_date > m.claim_line_end_date then 'invalid'
        when m.claim_line_end_date is null then 'null'
        else 'valid'
    end as bucket_name
    , case
        when m.claim_line_end_date > tuva_last_run then 'future'
        when m.claim_line_end_date < {{ dbt.dateadd(datepart="year", interval=-10, from_date_or_timestamp="cte.tuva_last_run") }} then 'too old'
        when m.claim_line_end_date > m.claim_end_date then 'line date greater than claim date'
        else null
    end as invalid_reason
    , cast(claim_line_end_date as {{ dbt.type_string() }}) as field_value
    , '{{ var('tuva_last_run')}}' as tuva_last_run
from {{ ref('medical_claim')}} m
cross join tuva_last_run cte
