with source as (

    select * from {{ source('ecommerce', 'customers') }}

),

deduplicated as (

    -- La fuente es un snapshot completo. Si en el lake se acumulan varias
    -- extracciones, nos quedamos con la versión más reciente de cada cliente.
    select *
    from source
    qualify row_number() over (
        partition by customer_id
        order by _extracted_at desc, updated_at desc
    ) = 1

)

select
    customer_id,
    trim(first_name)          as first_name,
    trim(last_name)           as last_name,
    lower(trim(email))        as email,
    upper(trim(country_code)) as country_code,
    lower(trim(segment))      as segment,
    created_at,
    updated_at,
    _extracted_at
from deduplicated
