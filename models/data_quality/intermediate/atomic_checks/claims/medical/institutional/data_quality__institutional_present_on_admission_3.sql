{{ config(
    enabled = var('claims_enabled', False)
) }}

WITH BASE as (
    SELECT * 
    FROM {{ ref('medical_claim')}}
    WHERE CLAIM_TYPE = 'institutional'
),
UNIQUE_FIELD as (
    SELECT DISTINCT CLAIM_ID
        ,cast(Diagnosis_POA_3 as {{ dbt.type_string() }})  as Field
        ,DATA_SOURCE
    FROM BASE

),
CLAIM_GRAIN as (
    SELECT CLAIM_ID
        ,DATA_SOURCE
        ,count(*) as FREQUENCY
    from UNIQUE_FIELD 
    GROUP BY CLAIM_ID
        ,DATA_SOURCE
),
CLAIM_AGG as (
SELECT
    CLAIM_ID,
    DATA_SOURCE,
    {{ dbt.listagg(measure="coalesce(Field, 'null')", delimiter_text="', '", order_by_clause="order by Field desc") }} AS FIELD_AGGREGATED
FROM
    UNIQUE_FIELD
GROUP BY
    CLAIM_ID,
    DATA_SOURCE
	)
SELECT DISTINCT -- to bring to claim_ID grain 
    M.Data_SOURCE
    ,coalesce(cast(M.CLAIM_START_DATE as {{ dbt.type_string() }}),cast('1900-01-01' as {{ dbt.type_string() }})) AS SOURCE_DATE
    ,'MEDICAL_CLAIM' AS TABLE_NAME
    ,'Claim ID' AS DRILL_DOWN_KEY
    ,coalesce(M.CLAIM_ID, 'NULL') AS DRILL_DOWN_VALUE
    ,'institutional' AS CLAIM_TYPE
    ,'DIAGNOSIS_POA_3' AS FIELD_NAME
       ,case when CG.FREQUENCY > 1                then 'multiple' 
        when M.Diagnosis_POA_3 in ('Y','N')       then 'valid'
        when M.Diagnosis_POA_3 is null            then 'null'
                                                  else 'invalid' end as BUCKET_NAME
    ,cast(null as {{ dbt.type_string() }}) as INVALID_REASON
    ,CAST({{ substring('AGG.FIELD_AGGREGATED', 1, 255) }} as {{ dbt.type_string() }}) AS FIELD_VALUE
    , '{{ var('tuva_last_run')}}' as tuva_last_run
FROM BASE M
LEFT JOIN CLAIM_GRAIN CG ON M.CLAIM_ID = CG.CLAIM_ID AND M.Data_Source = CG.Data_Source
LEFT JOIN CLAIM_AGG AGG ON M.CLAIM_ID = AGG.CLAIM_ID AND M.Data_Source = AGG.Data_Source